﻿function Create-ServerReportLinux() {
    param(
        [Parameter (Mandatory=$true)]
        [string]$ComputerName,
        [string]$Workdir = "D:\passports",
        [string]$SearchBase = "OU=RGr Servers,DC=SHUVOE,DC=RG-RUS,DC=RU",
        [string]$SearchFilter = '(OperatingSystem -like "Windows*") -and (Name -notlike "CAU*") -and (Description -notlike "*Failover cluster virtual network name account*")',
        [string[]]$ADCompProp = @('OperatingSystem','Description','Location','SerialNumber','DestinationIndicator','CanonicalName'),
        [switch]$SaveXML
    )

    [Microsoft.ActiveDirectory.Management.ADComputer[]]$Servers = Get-ADComputer -Identity $ComputerName -Properties $ADCompProp
    for ($j = 0; $j -lt $Servers.Count; $j++) {
    [Microsoft.ActiveDirectory.Management.ADComputer]$Server = $Servers[$j]
        if (([system.net.dns]::Resolve("$($Server.Name)") -ne $null) -and (Test-Connection $Server.Name -Count 2)) {
            # Активируем сессию SSH до хоста
            # Для получения данных выбрали источником программу lshw. Нужно установить, если нет в дистрибутиве по умолчанию.
            # Важно! Распарсить выхлоп из под sudo с паролем оказалось тяжело,
            # поэтому на линукс серверах нужно разрешить запуск lshw из под sudo без ввода пароля
            $cred = Get-Credential
            New-SshSession -ComputerName $ComputerName -Credential $cred -Verbose
            [xml]$dataXml = $(Invoke-SSHCommand -Index 0 -Command "sudo lshw -xml").Output
            $osCpu = $(Invoke-SSHCommand -Index 0 -Command "lscpu -J").Output | ConvertFrom-Json
            $osDistrib = $(Invoke-SSHCommand -Index 0 -Command "hostnamectl | sed -n 's/Operating System: //p'").Output
            $osNetwork = $dataXml.list.node.node | Where-Object {$_.class -eq "network"}
            $osMemory = $($dataXml.list.node.node | Where-Object {$_.id -eq "core"}).node | Where-Object {$_.class -eq "memory"}
            $osStorage = $($dataXml.list.node.node | Where-Object {$_.id -eq "core"}).node | Where-Object {$_.class -eq "storage"}
            $osArch = $dataXml.list.node.width | Select-Object -ExpandProperty '#text'
            $osMemoryTotal = [math]::round($($($osMemory).size | Measure-Object -Property "#text" -Sum).Sum/1Gb, 2)
#            $osMemoryCount = $osMemory.Count
            if ($osMemoryCount -eq 0) {
                $osMemoryCount = 1
            }
            $osMemorySpeed = $($($osMemory | Where-Object {$_.id -eq "memory"}).node | Where-Object {$_.id -eq "bank:0"}).clock
#            $osCpu = $($dataXml.list.node.node | Where-Object {$_.id -eq "core"}).node | Where-Object {$_.class -eq "processor" -and $_.description -notlike "*empty*"}
#            $osCpuCount = $osCpu.Count
            [int]$osCpuCount = $osCpu.lscpu | Where-Object {$_.field -eq "Socket(s):"} | Select-Object data -ExpandProperty data
            $osCpuClockSpeed = [math]::round(($osCpu.lscpu | Where-Object {$_.field -eq "CPU MHz:"} | select data -ExpandProperty data)/1000, 2)
            $osCpuModel = $osCpu.lscpu | Where-Object {$_.field -eq "Model name:"} | Select-Object data -ExpandProperty data
            [int]$osCpuCoresPerSocket = $osCpu.lscpu | Where-Object {$_.field -eq "Core(s) per socket:"} | Select-Object data -ExpandProperty data
            [int]$osCpuCoresTotal = ($osCpuCount * $osCpuCoresPerSocket)
            $osLogicalCpu = $osCpu.lscpu | Where-Object {$_.field -eq "CPU(s):"} | Select-Object data -ExpandProperty data



            # Создаем XML документ
            [System.XML.XMLDocument]$oXmlDocument = New-Object System.XML.XMLDocument
            # Создаем корень XML
            [System.Xml.XmlElement]$oXmlRoot = $oXmlDocument.CreateElement("Server")
            # Применяем к XML документу корень
            $oXmlDocument.AppendChild($oXmlRoot) | Out-Null
            $oXmlRoot.SetAttribute("Name","$($Server.Name)") | Out-Null
            if ($dataXml.list.node.product -ne "Virtual Machine") {
                $oXmlRoot.SetAttribute("InventoryNumber","$($Server.SerialNumber)") | Out-Null
                $oXmlRoot.SetAttribute("Location","$($Server.Location)") | Out-Null
                $oXmlRoot.SetAttribute("DestinationIndicator","$($Server.DestinationIndicator)") | Out-Null
            }

            #region Определение роли сервера
            switch ($Servers.Description) {
                "*Mail*" {$Role = "Сервер приложений MS Exchange."}
                "*Domain*" {$Role = "Контроллер домена."}
                "*DB*" {$Role = "Сервер баз данных."}
                "*APP*" {$Role = "Сервер приложений."}
                "*EMS*" {$Role = "Сервер мониторинга EMS."}
                "*RUDIS*" {$Role = "Сервер приложений RUDIS."}
                "*Print*" {$Role = "Сервер печати."}
                "*SAP*" {$Role = "Сервер приложений SAP."}
                "*File*" {$Role = "Файловый сервер"}
                "*Hyper-V*" {$Role = "Хост виртуализации Hyper-V."}
                "*Terminal*" {$Role = "Терминальный сервер."}
                "*Web*" {$Role = "Сервер Web приложений."}
                "*Kubernet*" {$Role = "Узел Kubernets."}
                "*Load*" {$Role = "Балансировщик нагрузки."}
                default {$Role = "Роль сервера не определена!"}
            }
            $oXmlRoot.SetAttribute("Role","$($Role)")
            #endregion
            
            #region Получаем имя Hyper-V кластера для VM
            if ($dataXml.list.node.product -eq "Virtual Machine") {
                [string]$VMHost = $(Invoke-SSHCommand -Index 0 -Command "strings /var/lib/hyperv/.kvp_pool_3 | head -2 | tail -1").Output
                $VMClusterName = $VMHost
            }
            #endregion

            #region Платформа XML
            [System.Xml.XmlElement]$oXmlVendorInfo = $oXMLDocument.CreateElement("VendorInfo")
            $oXmlVendorInfo.SetAttribute("SerialNumber","$($dataXml.list.node.serial)") | Out-Null
            $oXmlVendorInfo.SetAttribute("Manufacturer","$($dataXml.list.node.vendor)") | Out-Null
            $oXmlVendorInfo.SetAttribute("Model","$($dataXml.list.node.product)") | Out-Null
            if ($dataXml.list.node.product -eq "Virtual Machine") {
                $oXmlVendorInfo.SetAttribute("Virtualized","YES") | Out-Null
                $oXmlVendorInfo.SetAttribute("VMClusterName","$($($VMClusterName).ToUpper())") | Out-Null
            } else {
                $oXmlVendorInfo.SetAttribute("Virtualized","NO") | Out-Null
            }
            $oXmlRoot.AppendChild($oXmlVendorInfo) | Out-Null
            #endregion

            #region Операционнная система XML
            [System.Xml.XmlElement]$oXmlOS = $oXMLDocument.CreateElement("OperatingSystem")
            $oXmlOS.SetAttribute("Name","$($osDistrib)") | Out-Null
            $oXmlOS.SetAttribute("Verion","$($osDistrib)") | Out-Null
            $oXmlOS.SetAttribute("Arch","$($osArch) bit") | Out-Null
            $oXmlRoot.AppendChild($oXmlOS) | Out-Null
            #endregion

            #region Память XML
            [System.Xml.XmlElement]$oXmlMemory = $oXMLDocument.CreateElement("Memory")
            $oXmlMemory.SetAttribute("Capacity","$($osMemoryTotal) Gb") | Out-Null
            $oXmlMemory.SetAttribute("Speed","$($osMemorySpeed)") | Out-Null
            foreach ($i in $osMemory) {
                $osMemoryCount++
            }
            $oXmlMemory.SetAttribute("Count","$($osMemoryCount)") | Out-Null
            $oXmlRoot.AppendChild($oXmlMemory) | Out-Null
            #endregion

            #region Процессор XML
            [System.Xml.XmlElement]$oXmlProcessor = $oXMLDocument.CreateElement("Processor")
            if ($osCpuCount -eq $null) {
                $oXmlProcessor.SetAttribute("Count","1") | Out-Null
            } else {
                $oXmlProcessor.SetAttribute("Count","$($osCpuCount)") | Out-Null
            }
            [System.Xml.XmlElement]$oXmlCPU = $oXMLDocument.CreateElement("CPU0")   
            $oXmlCPU.SetAttribute("Name","$($osCpuModel)") | Out-Null
            $oXmlCPU.SetAttribute("Speed","$($osCpuClockSpeed) GHz") | Out-Null
            $oXmlCPU.SetAttribute("Cores","$($osCpuCoresPerSocket)") | Out-Null
            $oXmlCPU.SetAttribute("LogicalCores","$($osCpuCoresTotal)") | Out-Null
            $oXmlProcessor.AppendChild($oXmlCPU) | Out-Null
            $oXmlRoot.AppendChild($oXmlProcessor) | Out-Null
            #endregion

            #region Сеть XML
            [System.Xml.XmlElement]$oXmlNetworkAdapter = $oXMLDocument.CreateElement("Network")
            [int]$osNicCount = 0
            foreach ($nic in $osNetwork) {
                [System.Xml.XmlElement]$oXmlNet = $oXMLDocument.CreateElement("NetworkAdapter$($osNicCount)")
                $osNetworkMask = $(Invoke-SSHCommand -Index 0 -Command "ip addr show $($nic.logicalname) | sed -n 's/inet .*\///p' | sed -n 's/brd.*//p'").Output
                $osDefRoute = $(Invoke-SSHCommand -Index 0 -Command "ip route | sed -n 's/default via//p' | sed -n 's/dev.*//p'").Output
                $osDefRoute = $osDefRoute.Trim()
                $osNetworkMask = $osNetworkMask.Trim()
                $oXmlNet.SetAttribute("Description","$($nic.description)") | Out-Null
                $oXmlNet.SetAttribute("IPAddress","$($nic.configuration.setting | Where-Object {$_.id -eq 'ip'} | Select-Object value -ExpandProperty value)") | Out-Null
                $oXmlNet.SetAttribute("IPSubnet","$($osNetworkMask)") | Out-Null
                $oXmlNet.SetAttribute("Gateway","$($osDefRoute)") | Out-Null
                $oXmlNet.SetAttribute("MACAddress","$($nic.serial)") | Out-Null
                $oXmlNetworkAdapter.AppendChild($oXmlNet) | Out-Null
                $osNicCount++    
            }
            if ($osNicCount -eq 0) {
                $oXmlNetworkAdapter.SetAttribute("Count","1") | Out-Null
            } else {
                $oXmlNetworkAdapter.SetAttribute("Count","$($osNicCount)") | Out-Null
            }
            $oXmlRoot.AppendChild($oXmlNetworkAdapter) | Out-Null
            #endregion

            #region Хранилище XML
            [System.Xml.XmlElement]$oXmlStorage = $oXMLDocument.CreateElement("Storage")
            # Физические диски
            [System.Xml.XmlElement]$oXmlPhysicalDisks = $oXmlDocument.CreateElement("PhysicalDisks")
            [int]$pDisk = 0
            foreach ($type in $osStorage) {
                $osDisks = $type.node | Where-Object {$_.class -eq "disk"}
                foreach ($disk in $osDisks) {
                    [System.Xml.XmlElement]$oXmlPhysicalDisk = $oXmlDocument.CreateElement("PhysicalDisk$($pDisk)")
                    $oXmlPhysicalDisk.SetAttribute("Size","$([math]::round($($($disk.size | Select-Object "#text" -ExpandProperty "#text")/1GB))) GB") | Out-Null
                    $oXmlPhysicalDisk.SetAttribute("Model","$($disk.product)") | Out-Null
                    $oXmlPhysicalDisk.SetAttribute("Interface","$($disk.businfo)") | Out-Null
                    $oXmlPhysicalDisks.AppendChild($oXmlPhysicalDisk) | Out-Null
                    $oXmlStorage.AppendChild($oXmlPhysicalDisks) | Out-Null
                    $pDisk++
                }
            }
            if ($pDisk -eq 0) {
                $oXmlPhysicalDisks.SetAttribute("Count","1") | Out-Null
            } else {
                $oXmlPhysicalDisks.SetAttribute("Count","$($pDisk)") | Out-Null
            }
            $oXmlRoot.AppendChild($oXmlStorage) | Out-Null

            # Логические диски
            [System.Xml.XmlElement]$oXmlLogicalDisks = $oXmlDocument.CreateElement("LogicalDisks")
            [int]$lDisk = 0
            foreach ($type in $osStorage) {
                $osDisks = $type.node | Where-Object {$_.class -eq "disk"}
                foreach ($disk in $osDisks) {
                    $osVolumes = $disk.node | Where-Object {$_.class -eq "volume"}
                    foreach ($volume in $osVolumes) {
                        [System.Xml.XmlElement]$oXmlLogicalDisk = $oXMLDocument.CreateElement("LogicalDisk$($lDisk)")
                        $oXmlLogicalDisk.SetAttribute("DeviceID","$([string]$volume.logicalname)") | Out-Null
                        $oXmlLogicalDisk.SetAttribute("Size","$([math]::round($volume.capacity/1Gb, 1)) GB") | Out-Null
                        $oXmlLogicalDisk.SetAttribute("FileSystem","$($volume.configuration.setting | Where-Object {$_.id -eq "mount.fstype"} | Select-Object value -ExpandProperty value )") | Out-Null
                        $oXmlLogicalDisk.SetAttribute("Label","-") | Out-Null
                        $oXmlLogicalDisks.AppendChild($oXmlLogicalDisk) | Out-Null
                        $oXmlStorage.AppendChild($oXmlLogicalDisks) | Out-Null
                        $lDisk++
                    }
                }
            }
            if ($lDisk -eq 0) {
                $oXmlLogicalDisks.SetAttribute("Count","1") | Out-Null
            } else {
                $oXmlLogicalDisks.SetAttribute("Count","$($lDisk)") | Out-Null
            }
            #endregion

            #region IPMI XML
#                if ($oWmiSystem.Model -ne "Virtual Machine") {
#                    if (($oWmiSystem.Manufacturer -eq "HP") -and ((Get-Wmiobject -ComputerName $Server.Name -Class "__Namespace" -Namespace "root" | Where-Object {$_.name -eq "HPQ"}) -ne $null)) {
#                        $IPMIFirmware =  Get-WmiObject -Computername $Server.Name -Namespace "root\hpq" -Query "select * from HP_MPFirmware"
#                        $IPMIIntserface = Get-WmiObject -Computername $Server.Name -Namespace "root\hpq" -Query ("ASSOCIATORS OF {HP_MPFirmware.InstanceID='" + $IPMIFirmware.InstanceID + "'} WHERE AssocClass=HP_MPInstalledFirmwareIdentity")
#                        [System.Xml.XmlElement]$oXmlIPMI = $oXMLDocument.CreateElement("IPMI")
#                        $oXmlIPMI.SetAttribute("Type",$($IPMIIntserface.Name)) | Out-Null
#                        $oXmlIPMI.SetAttribute("Version",$($IPMIFirmware.VersionString)) | Out-Null
#                        $oXmlIPMI.SetAttribute("ID",$($IPMIIntserface.UniqueIdentifier)) | Out-Null
#                        $oXmlIPMI.SetAttribute("IPAddress",$($IPMIIntserface.IPv4Address)) | Out-Null
#                        $oXmlRoot.AppendChild($oXmlIPMI)
#                        } elseif (($oWmiSystem.Manufacturer -eq "Dell Inc.") -and ((Get-Wmiobject -ComputerName $Server.Name -Class "__Namespace" -Namespace "root\cimv2" | Where-Object {$_.name -eq "Dell"}) -ne $null)) {
#                            $IPMIFirmware =  Get-WmiObject -ComputerName $Server.Name -Namespace "root\cimv2\dell" -Query "SELECT * FROM DELL_Firmware WHERE Name like 'iDRAC%'"
#                            $IPMIIntserface = Get-WmiObject -ComputerName $Server.Name -Namespace "root\cimv2\dell" -Class DELL_RemoteAccessServicePort
#                            [System.Xml.XmlElement]$oXmlIPMI = $oXMLDocument.CreateElement("IPMI")
#                            $oXmlIPMI.SetAttribute("Type",$($IPMIFirmware.Name)) | Out-Null
#                            $oXmlIPMI.SetAttribute("Version",$($IPMIFirmware.Version)) | Out-Null
#                            $oXmlIPMI.SetAttribute("IPAddress",$($IPMIIntserface.AccessInfo)) | Out-Null
#                            $oXmlRoot.AppendChild($oXmlIPMI)
#                        }
#                }
            #endregion

            # Сохранение XML
            if ($SaveXML -eq $true) {
                if (Test-Path "$Workdir\xml" -eq $false) {
                    New-Item -Type Directory -Path "$Workdir\xml"
                }
                $oXmlDocument.Save("$Workdir\xml\$($Server.Name).xml")
            }

            #### Генерация DOCX файла с отчетом ####

            [Microsoft.Office.Interop.Word.ApplicationClass]$WordApp = New-Object -ComObject word.application
            $WordApp.Visible = $false
            $Document = $WordApp.Documents.Add()
            $WordApp.ActiveDocument.TextEncoding = [Microsoft.Office.Core.MsoEncoding]::msoEncodingUTF8
            $WordApp.ActiveDocument.SaveEncoding = [Microsoft.Office.Core.MsoEncoding]::msoEncodingUTF8
            $Selection = $WordApp.Selection

            #region Колонтитул
            $header = $Selection.Sections.Item(1).Headers.Item(1)
                # Параграф с именем сервера
            $header.Range.Paragraphs.Add()
            $pServerName = $header.Range.Paragraphs.Item(1)
            $pServerName.Range.Font.Size = 28
            $pServerName.Range.Font.Color = [Microsoft.Office.Interop.Word.wdColor]::wdColorGray45
            $header.Range.Text = "$($oXmlDocument.Server.Name.ToUpper())"
                # Параграф с картинкой
            $header.Range.Paragraphs.Add()
            $pRGrImage = $header.Range.Paragraphs.Item(2)
            $pRGrImage.Range.Paragraphs.Format.Alignment = 1
            $pRGrImage.Range.InlineShapes.AddPicture("$Workdir\rgr.jpg")
                # Параграф с текстом
            $header.Range.Paragraphs.Add()
            $pText = $header.Range.Paragraphs.Item(3)
            $pText.Range.Font.Size = 11
            $pText.Range.Text = "Паспорт технического средства"
            #endregion

            #region Описание сервера
            $Selection.Range.ParagraphFormat.SpaceAfter = 0
            $Selection.TypeText("Тип: сервер")
            $Selection.TypeParagraph()
            if ($oXmlDocument.Server.VendorInfo.Virtualized -eq "NO") {
                $Virt = "нет"
                } else {
                    $Virt = "да"
            }
            $Selection.TypeText("Виртуальный: $($Virt)")
            $Selection.TypeParagraph()
            if ($oXmlDocument.Server.VendorInfo.Virtualized -eq "NO") {
                $Selection.TypeText("Размещение: $($oXmlDocument.Server.Location)")
                $Selection.TypeParagraph()
                $Selection.TypeText("Положение в серверном шкафу: $($oXmlDocument.Server.DestinationIndicator)")
                $Selection.TypeParagraph()
                $Selection.TypeText("Инвентарный номер: $($oXmlDocument.Server.InventoryNumber)")
                $Selection.TypeParagraph()
                $Selection.TypeText("Серийный номер: $($oXmlDocument.Server.VendorInfo.SerialNumber.ToUpper())")
                $Selection.TypeParagraph()
                $Selection.TypeText("Производитель: $($oXmlDocument.Server.VendorInfo.Manufacturer)")
                $Selection.TypeParagraph()
                $Selection.TypeText("Модель: $($oXmlDocument.Server.VendorInfo.Model)")
            } else {
                $Selection.TypeText("Размещение: $($oXmlDocument.Server.VendorInfo.VMClusterName.ToUpper())")
                $Selection.TypeParagraph()
                $Selection.TypeText("Номер виртуальной машины: $($oXmlDocument.Server.VendorInfo.SerialNumber.ToUpper())")
            }
                $Selection.TypeParagraph()
                $Selection.TypeText("Роли:")
                $Selection.TypeParagraph()
                $Selection.TypeText("$Role")
                $Selection.InsertParagraphAfter()
                $Selection.MoveDown()
            #endregion

            #region Таблица Операционная система
            $Selection.TypeParagraph()
            $Selection.Font.Bold = $true
            $Selection.Range.ParagraphFormat.SpaceAfter = 0
            $Selection.TypeText("Операционная система")
            $Selection.MoveDown()
            $Selection.Font.Bold = $false
                # Рисуем таблицу
            $tOS = $WordApp.ActiveDocument.Tables.Add($Selection.Range, 4,2)
            $tOS.Borders.OutsideLineStyle = 1
            $tOS.Borders.InsideLineStyle = 1
            $tOS.Style.Table.RightPadding = 3
            $tOS.Style.Table.AllowBreakAcrossPage = 1
            $tOS.Columns.Item(1).Width = 150
            $tOS.Columns.Item(2).Width = 350
            $tOS.Rows.SpaceBetweenColumns = 11
            $tOS.Range.ParagraphFormat.SpaceAfter = 0
            $FirstRowCells = $tOS.Range.Columns.Item(1).cells
            foreach ($cell in $FirstRowCells) {
                $cell.Range.Bold = $true
            }
                # Заполняем ячейки (ячейка, ряд)
            $tOS.Cell(1,1).Range.Text = "Полное имя"
            $tOS.Cell(2,1).Range.Text = "Версия"
            $tOS.Cell(3,1).Range.Text = "Пакет обновлений"
            $tOS.Cell(4,1).Range.Text = "Архитектура"
            $tOS.Cell(1,2).Range.Text = "$($oXmlDocument.Server.OperatingSystem.Name.ToUpper())"
            $tOS.Cell(2,2).Range.Text = "$($oXmlDocument.Server.OperatingSystem.Verion)"
            $tOS.Cell(3,2).Range.Text = "$($oXmlDocument.Server.OperatingSystem.SP)"
            $tOS.Cell(4,2).Range.Text = "$($oXmlDocument.Server.OperatingSystem.Arch)"
            $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
            #endregion

            #region Таблица CPU
            $Selection.TypeParagraph()
            $Selection.Range.ParagraphFormat.SpaceAfter = 0
            $Selection.Font.Bold = $true
            $Selection.TypeText("Центральный процессор")
            $Selection.MoveDown()
            $Selection.Font.Bold = $false
                # Рисуем таблицу
            $tCPU = $WordApp.ActiveDocument.Tables.Add($Selection.Range, 5,2)
            $tCPU.Borders.OutsideLineStyle = 1
            $tCPU.Borders.InsideLineStyle = 1
            $tCPU.Style.Table.RightPadding = 3
            $tCPU.Style.Table.AllowBreakAcrossPage = 1
            $tCPU.Columns.Item(1).Width = 150
            $tCPU.Columns.Item(2).Width = 350
            $tCPU.Rows.SpaceBetweenColumns = 11
            $tCPU.Range.ParagraphFormat.SpaceAfter = 0
            $FirstRowCells = $tCPU.Range.Columns.Item(1).cells
            foreach ($cell in $FirstRowCells) {
                $cell.Range.Bold = $true
            }
                # Заполняем ячейки (ячейка, ряд)
            $tCPU.Cell(1,1).Range.Text = "Модель"
            $tCPU.Cell(2,1).Range.Text = "Частота"
            $tCPU.Cell(3,1).Range.Text = "Количество"
            $tCPU.Cell(4,1).Range.Text = "Количество ядер"
            $tCPU.Cell(5,1).Range.Text = "Количество логических ядер"
            $tCPU.Cell(1,2).Range.Text = "$($oXmlDocument.Server.Processor.CPU0.Name)"
            $tCPU.Cell(2,2).Range.Text = "$($oXmlDocument.Server.Processor.CPU0.Speed)"
            $tCPU.Cell(3,2).Range.Text = "$($oXmlDocument.Server.Processor.Count)"
            $tCPU.Cell(4,2).Range.Text = "$($oXmlDocument.Server.Processor.CPU0.Cores)"
            $tCPU.Cell(5,2).Range.Text = "$($oXmlDocument.Server.Processor.CPU0.LogicalCores)"
            $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
            $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
            #endregion

            #region Таблица Memory
            $Selection.TypeParagraph()
            $Selection.Range.ParagraphFormat.SpaceAfter = 0
            $Selection.Font.Bold = $true
            $Selection.TypeText("Оперативная память")
            $Selection.MoveDown()
            $Selection.Font.Bold = $false
                # Рисуем таблицу
            $tMem = $WordApp.ActiveDocument.Tables.Add($Selection.Range, 3,2)
            $tMem.Borders.OutsideLineStyle = 1
            $tMem.Borders.InsideLineStyle = 1
            $tMem.Style.Table.RightPadding = 3
            $tMem.Style.Table.AllowBreakAcrossPage = 1
            $tMem.Columns.Item(1).Width = 150
            $tMem.Columns.Item(2).Width = 350
            $tMem.Rows.SpaceBetweenColumns = 11
            $tMem.Range.ParagraphFormat.SpaceAfter = 0
            $FirstRowCells = $tMem.Range.Columns.Item(1).cells
            foreach ($cell in $FirstRowCells) {
                 $cell.Range.Bold = $true
            }
                # Заполняем ячейки (ячейка, ряд)
            $tMem.Cell(1,1).Range.Text = "Количество модулей"
            $tMem.Cell(2,1).Range.Text = "Частота модулей"
            $tMem.Cell(3,1).Range.Text = "Общий объем"
            $tMem.Cell(1,2).Range.Text = "$($oXmlDocument.Server.Memory.Count)"
            if ($oXmlDocument.Server.VendorInfo.Virtualized -eq "YES") {
                $tMem.Cell(2,2).Range.Text = "-"
            } else {
                $tMem.Cell(2,2).Range.Text = "$($oXmlDocument.Server.Memory.Speed)"
            }
            $tMem.Cell(3,2).Range.Text = "$($oXmlDocument.Server.Memory.Capacity)"
            $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
            #endregion

            #region Таблицы Storage
            $Selection.TypeParagraph()
            $Selection.Range.ParagraphFormat.SpaceAfter = 0
            $Selection.Font.Bold = $true
            $Selection.TypeText("Устройства хранения")
            $Selection.Font.Bold = $false
            for ($i = 0; $i -lt $oXmlDocument.Server.Storage.PhysicalDisks.Count; $i++) {
                $DiskNumber = "PhysicalDisk" + $i
                $Selection.TypeParagraph()
                $Selection.MoveDown()
                # Рисуем таблицу
                $tStr = $WordApp.ActiveDocument.Tables.Add($Selection.Range, 3,3)
                $tStr.Borders.OutsideLineStyle = 1
                $tStr.Borders.InsideLineStyle = 1
                $tStr.Style.Table.RightPadding = 3
                $tStr.Style.Table.AllowBreakAcrossPage = 1
                $tStr.Columns.Item(1).Width = 100
                $tStr.Columns.Item(2).Width = 200
                $tStr.Columns.Item(3).Width = 200
                $tStr.Rows.SpaceBetweenColumns = 11
                $tStr.Range.ParagraphFormat.SpaceAfter = 0
                $tStr.Rows.Item(1).cells.item(1).merge($tStr.Rows.Item(1).cells.item(3))
                $tStr.Cell(1,1).Range.Font.Bold = $true
                    # Заполняем ячейки (ряд, ячейка)
                $tStr.Cell(1,1).Range.Text = "$($oXmlDocument.Server.Storage.PhysicalDisks.$DiskNumber.Model)"
                $tStr.Cell(1,1).Range.ParagraphFormat.Alignment = 1
                $tStr.Cell(2,1).Range.Text = "RAID"
                $tStr.Cell(2,2).Range.Text = "Интерфейс"
                $tStr.Cell(2,3).Range.Text = "Объем"
                switch ($oXmlDocument.Server.VendorInfo.Virtualized) {
                    "YES" {$tStr.Cell(3,1).Range.Text = "-"}
                    "NO" {$tStr.Cell(3,1).Range.Text = "#ЗАПОЛНИТЬ#"}
                }
                $tStr.Cell(3,2).Range.Text = "$($oXmlDocument.Server.Storage.PhysicalDisks.$DiskNumber.Interface)"
                $tStr.Cell(3,3).Range.Text = "$($oXmlDocument.Server.Storage.PhysicalDisks.$DiskNumber.Size)"
                $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
            }
            #endregion

            #region Таблицы Файловые системы
            $Selection.TypeParagraph()
            $Selection.Range.ParagraphFormat.SpaceAfter = 0
            $Selection.Font.Bold = $true
            $Selection.TypeText("Файловые системы")
            $Selection.Font.Bold = $false
            $Selection.TypeParagraph()
            $Selection.MoveDown()
                # Рисуем таблицу
            $tFS = $WordApp.ActiveDocument.Tables.Add($Selection.Range, $([int]$oXmlDocument.Server.Storage.LogicalDisks.Count + 1),4)
            $tFS.Borders.OutsideLineStyle = 1
            $tFS.Borders.InsideLineStyle = 1
            $tFS.Style.Table.RightPadding = 3
            $tFS.Style.Table.AllowBreakAcrossPage = 1
            $tFS.Columns.Item(1).Width = 125
            $tFS.Columns.Item(2).Width = 75
            $tFS.Columns.Item(3).Width = 100
            $tFS.Columns.Item(4).Width = 200
            $tFS.Rows.SpaceBetweenColumns = 11
            $tFS.Range.ParagraphFormat.SpaceAfter = 0
            $tFS.Cell(1,1).Range.Text = "Точка монтирования"
            $tFS.Cell(1,2).Range.Text = "Метка"
            $tFS.Cell(1,3).Range.Text = "Файловая система"
            $tFS.Cell(1,4).Range.Text = "Размер"
            $FirstRowCells = $tFS.Rows.Item(1)
            foreach ($cell in $FirstRowCells) {
                $cell.Range.Bold = $true
                $cell.Range.ParagraphFormat.Alignment = 1
            }
            Clear-Variable FirstRowCells
            for ($i = 0; $i -lt $oXmlDocument.Server.Storage.LogicalDisks.Count; $i++) {
                $FSNumber = "LogicalDisk" + $i
                    # Заполняем ячейки (ряд, ячейка)
                $tFS.Cell($i+2,1).Range.Text = "$($oXmlDocument.Server.Storage.LogicalDisks.$FSNumber.DeviceID)"
                $tFS.Cell($i+2,2).Range.Text = "$($oXmlDocument.Server.Storage.LogicalDisks.$FSNumber.Label)"
                $tFS.Cell($i+2,3).Range.Text = "$($oXmlDocument.Server.Storage.LogicalDisks.$FSNumber.FileSystem)"
                $tFS.Cell($i+2,4).Range.Text = "$($oXmlDocument.Server.Storage.LogicalDisks.$FSNumber.Size)"
                $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
            }
            #endregion

            #region Таблица Сетевые интерфейсы
            if (($oXmlDocument.Server.Network.Count -gt 1) -and ($oXmlDocument.Server.Storage.PhysicalDisks.Count -lt 2)) {
                $Selection.InsertNewPage()
                $Selection.TypeParagraph()
            } else {
                $Selection.TypeParagraph()
            }
            $Selection.Range.ParagraphFormat.SpaceAfter = 0
            $Selection.Font.Bold = $true
            $Selection.TypeText("Сетевые интерфейсы")
            $Selection.Font.Bold = $false
            $Selection.TypeParagraph()
            $Selection.MoveDown()
                # Рисуем таблицу
            for ($i = 0; $i -lt $oXmlDocument.Server.Network.Count; $i++) {
                $NetAdapterNumber = "NetworkAdapter" + $i
                $tNIC = $WordApp.ActiveDocument.Tables.Add($Selection.Range, 6,2)
                $tNIC.Borders.OutsideLineStyle = 1
                $tNIC.Borders.InsideLineStyle = 1
                $tNIC.Style.Table.RightPadding = 3
                $tNIC.Style.Table.AllowBreakAcrossPage = 1
                $tNIC.Columns.Item(1).Width = 125
                $tNIC.Columns.Item(2).Width = 375
                $tNIC.Rows.SpaceBetweenColumns = 11
                $tNIC.Range.ParagraphFormat.SpaceAfter = 0
                $FirstRowCells = $tNIC.Range.Columns.Item(1).Cells
                foreach ($cell in $FirstRowCells) {
                    $cell.Range.Bold = $true
                }
                $tNIC.Rows.Item(1).Cells.Item(1).Merge($tNIC.Rows.Item(1).cells.item(2))
                $tNIC.Cell(1,1).Range.Font.Bold = $true
                    # Заполняем ячейки (ряд, ячейка)
                $tNIC.Cell(1,1).Range.Text = "$($oXmlDocument.Server.Network.$NetAdapterNumber.Name)"
                $tNIC.Cell(1,1).Range.ParagraphFormat.Alignment = 1
                $tNIC.Cell(2,1).Range.Text = "Имя"
                $tNIC.Cell(3,1).Range.Text = "IP адрес"
                $tNIC.Cell(4,1).Range.Text = "Сетевая маска"
                $tNIC.Cell(5,1).Range.Text = "Шлюз по умолчанию"
                $tNIC.Cell(6,1).Range.Text = "MAC адрес"
                $tNIC.Cell(2,2).Range.Text = "$($oXmlDocument.Server.Network.$NetAdapterNumber.Description)"
                $tNIC.Cell(3,2).Range.Text = "$($oXmlDocument.Server.Network.$NetAdapterNumber.IPAddress)"
                $tNIC.Cell(4,2).Range.Text = "$($oXmlDocument.Server.Network.$NetAdapterNumber.IPSubnet)"
                $tNIC.Cell(5,2).Range.Text = "$($oXmlDocument.Server.Network.$NetAdapterNumber.Gateway)"
                $tNIC.Cell(6,2).Range.Text = "$($oXmlDocument.Server.Network.$NetAdapterNumber.MACAddress)"
                $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
                $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
                $Selection.TypeParagraph()
            }
            #endregion

            #region Таблица IPMI
            if (($oWmiSystem.Model -ne "Virtual Machine") -and (($oWmiSystem.Manufacturer -eq "HP") -or ($oWmiSystem.Manufacturer -eq "Dell Inc."))) {
                $Selection.Range.ParagraphFormat.SpaceAfter = 0
                $Selection.Font.Bold = $true
                $Selection.TypeText("Интерфейс управления")
                $Selection.Font.Bold = $false
                $Selection.TypeParagraph()
                $Selection.MoveDown()
                    # Рисуем таблицу
                switch ($oXmlDocument.Server.VendorInfo.Manufacturer) {
                    "HP" { $tIPMI = $WordApp.ActiveDocument.Tables.Add($Selection.Range, 4,2) }
                    "Dell Inc." { $tIPMI = $WordApp.ActiveDocument.Tables.Add($Selection.Range, 3,2) }
                }
                $tIPMI.Borders.OutsideLineStyle = 1
                $tIPMI.Borders.InsideLineStyle = 1
                $tIPMI.Style.Table.RightPadding = 3
                $tIPMI.Style.Table.AllowBreakAcrossPage = 1
                $tIPMI.Columns.Item(1).Width = 150
                $tIPMI.Columns.Item(2).Width = 350
                $tIPMI.Rows.SpaceBetweenColumns = 11
                $tIPMI.Range.ParagraphFormat.SpaceAfter = 0
                $FirstRowCells = $tIPMI.Range.Columns.Item(1).Cells
                foreach ($cell in $FirstRowCells) {
                    $cell.Range.Bold = $true
                }
                    # Заполняем ячейки (ряд, ячейка)
                if ($oXmlDocument.Server.VendorInfo.Manufacturer -eq "HP") {
                    $tIPMI.Cell(1,1).Range.Text = "Тип"
                    $tIPMI.Cell(2,1).Range.Text = "Версия"
                    $tIPMI.Cell(3,1).Range.Text = "Идентификационный номер"
                    $tIPMI.Cell(4,1).Range.Text = "IP адрес"
                    $tIPMI.Cell(1,2).Range.Text = "$($oXmlDocument.Server.IPMI.Type)"
                    $tIPMI.Cell(2,2).Range.Text = "$($oXmlDocument.Server.IPMI.Version)"
                    $tIPMI.Cell(3,2).Range.Text = "$($oXmlDocument.Server.IPMI.ID)"
                    $tIPMI.Cell(4,2).Range.Text = "$($oXmlDocument.Server.IPMI.IPAddress)"
                } elseif ($oXmlDocument.Server.VendorInfo.Manufacturer -eq "Dell Inc.") {
                    $tIPMI.Cell(1,1).Range.Text = "Тип"
                    $tIPMI.Cell(2,1).Range.Text = "Версия"
                    $tIPMI.Cell(3,1).Range.Text = "IP адрес"
                    $tIPMI.Cell(1,2).Range.Text = "$($oXmlDocument.Server.IPMI.Type)"
                    $tIPMI.Cell(2,2).Range.Text = "$($oXmlDocument.Server.IPMI.Version)"
                    $tIPMI.Cell(3,2).Range.Text = "$($oXmlDocument.Server.IPMI.IPAddress)"
                }
                    $Selection.MoveDown([Microsoft.Office.Interop.Word.WdUnits]::wdScreen)
            }
            #endregion
            
            #region Сохранение DOCX
            if ((Test-Path "$Workdir\docx") -eq $false) {
                New-Item -Type Directory -Path "$Workdir\docx"
            }
            $Document.SaveAs([ref]$("$Workdir\docx\$($Server.Name).docx"),[ref]$([Microsoft.Office.Interop.Word.WdSaveFormat]::wdFormatDocumentDefault))
            $WordApp.Quit()
            #$null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$WordApp)
            Remove-Variable oXmlDocument, WordApp
            #endregion

            Write-Progress -Activity “Found computers: $($Servers.Count). Gathering information...” -status “Complete $($j+1)” -percentComplete (($j/$Servers.count)*100)
            Remove-SSHSession -Index 0
        } else {
                "Cannot connect to host $($Server.Name)" | Out-File "$Workdir\errors.txt" -Encoding utf8
        }
    }
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
}