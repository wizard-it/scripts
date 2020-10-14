function Create-ServerReport() {
    param(
        [string]$ComputerName,
        [string]$Workdir = "D:\passports",
        [string]$SearchBase = "OU=RGr Servers,DC=SHUVOE,DC=RG-RUS,DC=RU",
        [string]$SearchFilter = '(OperatingSystem -like "Windows*") -and (Name -notlike "CAU*") -and (Description -notlike "*Failover cluster virtual network name account*")',
        [string[]]$ADCompProp = @('OperatingSystem','Description','Location','SerialNumber','DestinationIndicator','CanonicalName'),
        [switch]$AD,
        [switch]$SaveXML
    )
    if ($AD -eq $true) {
        [Microsoft.ActiveDirectory.Management.ADComputer[]]$Servers = Get-ADComputer -SearchBase $SearchBase -Properties $ADCompProp -Filter $SearchFilter
        [Microsoft.ActiveDirectory.Management.ADComputer[]]$DomainControllers = Get-ADComputer -Properties $ADCompProp -SearchBase $((Get-ADDomain).DomainControllersContainer) -Filter {Description -like "*DC*"}
        foreach ($DC in $DomainControllers) {
            [Microsoft.ActiveDirectory.Management.ADComputer[]]$Servers += $DC
            }
        } else {
            [Microsoft.ActiveDirectory.Management.ADComputer[]]$Servers = Get-ADComputer -Identity $ComputerName -Properties $ADCompProp
    }
    for ($j = 0; $j -lt $Servers.Count; $j++) {
    [Microsoft.ActiveDirectory.Management.ADComputer]$Server = $Servers[$j]
        if (([system.net.dns]::Resolve("$($Server.Name)") -ne $null) -and (Test-Connection $Server.Name -Count 2) -and ($oWmiBios = Get-WmiObject -Class win32_bios -ComputerName $Server.Name)) {
            $oWmiSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Server.Name
            $oWmiProcessor = Get-WmiObject -Class Win32_Processor -ComputerName $Server.Name | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed
            $oWmiOS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Server.Name
            if ($oWmiOS.Version -like "5.*") {
                if ($oWmiProcessor.count -eq $null) {
                $OSArch = [string](Get-WmiObject -Class Win32_Processor -ComputerName $Server.Name -Property AddressWidth).AddressWidth + "-bit"
                } else {
                    $OSArch = [string](Get-WmiObject -Class Win32_Processor -ComputerName $Server.Name -Property AddressWidth)[0].AddressWidth + "-bit"
                }
            }
            $oWmiMemory = Get-WmiObject -Class Win32_PhysicalMemory -ComputerName $Server.Name
            $oWmiNetAdapter = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $Server.Name| ? {$_.ipaddress -ne $NULL} | Select-Object IPAddress,IPSubnet,DefaultIPGateway,MACAddress,Description
            $oWmiLogicalDisks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $Server.Name | ? {(($_.Description -eq "Local Fixed Disk") -or ($_.Description -eq "Локальный жесткий диск")) -and ($_.Filesystem -eq "NTFS")}
            $oWmiPhysicalDisks = Get-WmiObject -Class Win32_DiskDrive -ComputerName $Server.Name | Select-Object Model,Size,InterfaceType | Where-Object {$_.Size -gt 5000}

            # Создаем XML документ
                [System.XML.XMLDocument]$oXmlDocument = New-Object System.XML.XMLDocument
                # Создаем корень XML
                [System.Xml.XmlElement]$oXmlRoot = $oXmlDocument.CreateElement("Server")
                # Применяем к XML документу корень
                $oXmlDocument.AppendChild($oXmlRoot) | Out-Null
                $oXmlRoot.SetAttribute("Name","$($Server.Name)") | Out-Null
                if ($oWmiSystem.Model -ne "Virtual Machine") {
                    $oXmlRoot.SetAttribute("InventoryNumber","$($Server.SerialNumber)") | Out-Null
                    $oXmlRoot.SetAttribute("Location","$($Server.Location)") | Out-Null
                    $oXmlRoot.SetAttribute("DestinationIndicator","$($Server.DestinationIndicator)") | Out-Null
                }

            #region Определение роли сервера
            switch -wildcard ($Server.Description) {
                "*Mail*" {$Role = "Сервер приложений MS Exchange."}
                "DB" {$Role = "Сервер баз данных."}
                "APP" {$Role = "Сервер приложений."}
                "EMS" {$Role = "Сервер мониторинга EMS."}
                "RUDIS" {$Role = "Сервер приложений RUDIS."}
                "Print*" {$Role = "Сервер печати."}
                "SAP*" {$Role = "Сервер приложений SAP."}
                "File*" {$Role = "Файловый сервер"}
                "Hyper-V" {$Role = "Хост виртуализации Hyper-V."}
                "Terminal*" {$Role = "Терминальный сервер."}
                "Web*" {$Role = "Сервер Web приложений."}
                default {$Role = "Роль сервера не определена!"}
            }
            $oXmlRoot.SetAttribute("Role","$($Role)")
            #endregion
            
            #region Получаем имя Hyper-V кластера для VM
            if ($oWmiSystem.Model -eq "Virtual Machine") {
                $RemoteHKLM = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Server.Name)
                [string]$VMHost = $RemoteHKLM.OpenSubKey("SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters").GetValue("HostName")
                $RemoteHKLM.Close()
                $IsVMHostClustered = Get-WmiObject -ComputerName $VMHost -Namespace root -Class "__Namespace" | Where-Object {$_.name -eq "MSCluster"}
                if ($IsVMHostClustered -eq $null) {
                    [string]$VMClusterName = $VMHost -replace ".$env:USERDNSDOMAIN$"
                } else {
                    [string]$VMClusterName = (Get-WmiObject -ComputerName $VMHost -Namespace "root\mscluster" -Class MSCluster_Cluster).Name
                }
                Clear-Variable RemoteHKLM
                Remove-Variable RemoteHKLM
            }
            #endregion

            #region Платформа XML
                [System.Xml.XmlElement]$oXmlVendorInfo = $oXMLDocument.CreateElement("VendorInfo")
                $oXmlVendorInfo.SetAttribute("SerialNumber","$($oWmiBios.SerialNumber)") | Out-Null
                $oXmlVendorInfo.SetAttribute("Manufacturer","$($oWmiBios.Manufacturer)") | Out-Null
                $oXmlVendorInfo.SetAttribute("Model","$($oWmiSystem.Model)") | Out-Null
                if ($oWmiSystem.Model -eq "Virtual Machine") {
                    $oXmlVendorInfo.SetAttribute("Virtualized","YES") | Out-Null
                    $oXmlVendorInfo.SetAttribute("VMClusterName","$($($VMClusterName).ToUpper())") | Out-Null
                    } else {
                        $oXmlVendorInfo.SetAttribute("Virtualized","NO") | Out-Null
                    }
                $oXmlRoot.AppendChild($oXmlVendorInfo) | Out-Null
            #endregion

            #region Операционнная система XML
                [System.Xml.XmlElement]$oXmlOS = $oXMLDocument.CreateElement("OperatingSystem")
                $oXmlOS.SetAttribute("Name","$($oWmiOS.CSName).$(($env:USERDNSDOMAIN).ToLower())") | Out-Null
                $oXmlOS.SetAttribute("Verion","$($oWmiOS.Caption -replace "\s$")") | Out-Null
                if ($oWmiOS.CSDVersion -ne $null) {
                    $oXmlOS.SetAttribute("SP","$($oWmiOS.CSDVersion)") | Out-Null
                } else {
                    $oXmlOS.SetAttribute("SP","-") | Out-Null
                }
                if ($oWmiOS.Version -like "5.*") {
                    $oXmlOS.SetAttribute("Arch","$($OSArch)") | Out-Null
                    } else {
                        $oXmlOS.SetAttribute("Arch","$($oWmiOS.OSArchitecture)") | Out-Null
                    }
                $oXmlRoot.AppendChild($oXmlOS) | Out-Null
            #endregion

            #region Память XML
                [System.Xml.XmlElement]$oXmlMemory = $oXMLDocument.CreateElement("Memory")
                $oXmlMemory.SetAttribute("Capacity","$(($oWmiMemory | Measure-Object -Property Capacity -Sum).Sum/1Gb)GB") | Out-Null
                if ($oWmiMemory.count -eq $null) {
                    if ($oWmiSystem.Model -ne "Virtual Machine") {
                        $oXmlMemory.SetAttribute("Speed","$($oWmiMemory.Speed) MHz") | Out-Null
                        }
                    $oXmlMemory.SetAttribute("Count","1") | Out-Null
                    } else {
                        if ($oWmiSystem.Model -ne "Virtual Machine") {
                            $oXmlMemory.SetAttribute("Speed","$($oWmiMemory[0].Speed) MHz") | Out-Null
                            }
                        $oXmlMemory.SetAttribute("Count","$($oWmiMemory.Count)") | Out-Null
                    }
                $oXmlRoot.AppendChild($oXmlMemory) | Out-Null
            #endregion

            #region Процессор XML
                [System.Xml.XmlElement]$oXmlProcessor = $oXMLDocument.CreateElement("Processor")
                if ($oWmiProcessor.Count -eq $null) {
                    $oXmlProcessor.SetAttribute("Count","1") | Out-Null
                } else {
                    $oXmlProcessor.SetAttribute("Count","$($oWmiProcessor.count)") | Out-Null
                    }
                [int]$cpu = 0
                foreach ($oWmiCPU in $oWmiProcessor) {
                    [System.Xml.XmlElement]$oXmlCPU = $oXMLDocument.CreateElement("CPU$($cpu)")
                        $oXmlCPU.SetAttribute("Name","$($oWmiCPU.Name -replace "\s{2,2}" -replace "@.+$" -replace "\s$")") | Out-Null
                        if ($oWmiOS.Version -like "5.*") {
                            $oXmlCPU.SetAttribute("Speed","$($oWmiCPU.MaxClockSpeed) MHz") | Out-Null
                            } else {
                                $oXmlCPU.SetAttribute("Speed","$($oWmiCPU.Name -replace ".+@ ")") | Out-Null
                            }
                        $oXmlCPU.SetAttribute("Cores","$($oWmiCPU.NumberOfCores)") | Out-Null
                        $oXmlCPU.SetAttribute("LogicalCores","$($oWmiCPU.NumberOfLogicalProcessors)") | Out-Null
                        $oXmlProcessor.AppendChild($oXmlCPU) | Out-Null
                        $cpu++
                }
                $oXmlRoot.AppendChild($oXmlProcessor) | Out-Null
            #endregion

            #region Сеть XML
                [System.Xml.XmlElement]$oXmlNetworkAdapter = $oXMLDocument.CreateElement("Network")
                [int]$net = 0
                if ($oWmiNetAdapter.Count -eq $null) {
                    $oXmlNetworkAdapter.SetAttribute("Count","1") | Out-Null
                } else {
                    $oXmlNetworkAdapter.SetAttribute("Count","$($oWmiNetAdapter.Count)") | Out-Null
                }
                foreach ($oWmiNet in $oWmiNetAdapter) {
                    [System.Xml.XmlElement]$oXmlNet = $oXMLDocument.CreateElement("NetworkAdapter$($net)")
                        $oXmlNet.SetAttribute("Description","$($oWmiNet.Description)") | Out-Null
                        $oXmlNet.SetAttribute("IPAddress","$($oWmiNet.IPAddress[0])") | Out-Null
                        $oXmlNet.SetAttribute("IPSubnet","$($oWmiNet.IPSubnet[0])") | Out-Null
                        if ($oWmiNet.DefaultIPGateway -eq $null) {
                                $oXmlNet.SetAttribute("Gateway","-") | Out-Null
                            } else {
                                $oXmlNet.SetAttribute("Gateway","$($oWmiNet.DefaultIPGateway)") | Out-Null
                            }
                        $oXmlNet.SetAttribute("MACAddress","$($oWmiNet.MACAddress)") | Out-Null
                        $oXmlNetworkAdapter.AppendChild($oXmlNet) | Out-Null
                        $net++
                }
                $oXmlRoot.AppendChild($oXmlNetworkAdapter) | Out-Null
            #endregion

            #region Хранилище XML
            [System.Xml.XmlElement]$oXmlStorage = $oXMLDocument.CreateElement("Storage")
            # Физические диски
                [int]$pDisk = 0
                [System.Xml.XmlElement]$oXmlPhysicalDisks = $oXmlDocument.CreateElement("PhysicalDisks")
                if ($oWmiPhysicalDisks.count -eq $null) {
                    $oXmlPhysicalDisks.SetAttribute("Count","1") | Out-Null
                } else {
                    $oXmlPhysicalDisks.SetAttribute("Count","$($oWmiPhysicalDisks.count)") | Out-Null
                }
                foreach ($oWmiPhysicalDisk in $oWmiPhysicalDisks) {
                    [System.Xml.XmlElement]$oXmlPhysicalDisk = $oXmlDocument.CreateElement("PhysicalDisk$($pDisk)")
                        $oXmlPhysicalDisk.SetAttribute("Model","$($oWmiPhysicalDisk.Model)") | Out-Null
                        $oXmlPhysicalDisk.SetAttribute("Interface","$($oWmiPhysicalDisk.InterfaceType)") | Out-Null
                        $oXmlPhysicalDisk.SetAttribute("Size","$("{0:N2}" -f $($oWmiPhysicalDisk.Size/1Gb)) GB") | Out-Null
                        $oXmlPhysicalDisks.AppendChild($oXmlPhysicalDisk) | Out-Null
                        $oXmlStorage.AppendChild($oXmlPhysicalDisks) | Out-Null
                        $pDisk++
                }
                $oXmlRoot.AppendChild($oXmlStorage) | Out-Null
            # Логические диски
                [System.Xml.XmlElement]$oXmlLogicalDisks = $oXmlDocument.CreateElement("LogicalDisks")
                [int]$lDisk = 0
                if ($oWmiLogicalDisks.count -eq $null) {
                    $oXmlLogicalDisks.SetAttribute("Count","1") | Out-Null
                } else {
                    $oXmlLogicalDisks.SetAttribute("Count","$($oWmiLogicalDisks.count)") | Out-Null
                }
                foreach ($oWmiLogicalDisk in $oWmiLogicalDisks) {
                    [System.Xml.XmlElement]$oXmlLogicalDisk = $oXMLDocument.CreateElement("LogicalDisk$($lDisk)")
                    $oXmlLogicalDisk.SetAttribute("DeviceID","$($oWmiLogicalDisk.DeviceID)") | Out-Null
                    $oXmlLogicalDisk.SetAttribute("Size","$("{0:N2}" -f $($oWmiLogicalDisk.Size/1Gb)) GB") | Out-Null
                    $oXmlLogicalDisk.SetAttribute("FileSystem","$($oWmiLogicalDisk.FileSystem)") | Out-Null
                    $oXmlLogicalDisk.SetAttribute("Label","$($oWmiLogicalDisk.VolumeName)") | Out-Null
                    $oXmlLogicalDisks.AppendChild($oXmlLogicalDisk) | Out-Null
                    $oXmlStorage.AppendChild($oXmlLogicalDisks) | Out-Null
                    $lDisk++
                }
            #endregion

            #region IPMI XML
                if ($oWmiSystem.Model -ne "Virtual Machine") {
                    if (($oWmiSystem.Manufacturer -eq "HP") -and ((Get-Wmiobject -ComputerName $Server.Name -Class "__Namespace" -Namespace "root" | Where-Object {$_.name -eq "HPQ"}) -ne $null)) {
                        $IPMIFirmware =  Get-WmiObject -Computername $Server.Name -Namespace "root\hpq" -Query "select * from HP_MPFirmware"
                        $IPMIIntserface = Get-WmiObject -Computername $Server.Name -Namespace "root\hpq" -Query ("ASSOCIATORS OF {HP_MPFirmware.InstanceID='" + $IPMIFirmware.InstanceID + "'} WHERE AssocClass=HP_MPInstalledFirmwareIdentity")
                        [System.Xml.XmlElement]$oXmlIPMI = $oXMLDocument.CreateElement("IPMI")
                        $oXmlIPMI.SetAttribute("Type",$($IPMIIntserface.Name)) | Out-Null
                        $oXmlIPMI.SetAttribute("Version",$($IPMIFirmware.VersionString)) | Out-Null
                        $oXmlIPMI.SetAttribute("ID",$($IPMIIntserface.UniqueIdentifier)) | Out-Null
                        $oXmlIPMI.SetAttribute("IPAddress",$($IPMIIntserface.IPv4Address)) | Out-Null
                        $oXmlRoot.AppendChild($oXmlIPMI)
                        } elseif (($oWmiSystem.Manufacturer -eq "Dell Inc.") -and ((Get-Wmiobject -ComputerName $Server.Name -Class "__Namespace" -Namespace "root\cimv2" | Where-Object {$_.name -eq "Dell"}) -ne $null)) {
                            $IPMIFirmware =  Get-WmiObject -ComputerName $Server.Name -Namespace "root\cimv2\dell" -Query "SELECT * FROM DELL_Firmware WHERE Name like 'iDRAC%'"
                            $IPMIIntserface = Get-WmiObject -ComputerName $Server.Name -Namespace "root\cimv2\dell" -Class DELL_RemoteAccessServicePort
                            [System.Xml.XmlElement]$oXmlIPMI = $oXMLDocument.CreateElement("IPMI")
                            $oXmlIPMI.SetAttribute("Type",$($IPMIFirmware.Name)) | Out-Null
                            $oXmlIPMI.SetAttribute("Version",$($IPMIFirmware.Version)) | Out-Null
                            $oXmlIPMI.SetAttribute("IPAddress",$($IPMIIntserface.AccessInfo)) | Out-Null
                            $oXmlRoot.AppendChild($oXmlIPMI)
                        }
                }
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
            } else {
                "Cannot connect to host $($Server.Name)" | Out-File "$Workdir\errors.txt" -Encoding utf8
            }
    }
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
}