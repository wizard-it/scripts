function Create-ADUser() {
    <#
        .SYNOPSIS
        Создание нового пользователя в домене, его почтового ящика и личного сетевого диска.

        .DESCRIPTION
        Функция Create-ADUser оформлена в виде командлета PowerShell и предоставляет администратору средства для содания нового
        пользователя в домене AD DS. Помимо создания учетной записи и заполнения различных её полей, возможно создание почтового
        ящика в MS Exchange и каталога на файловом сервере предприятия.

        .EXAMPLE
        Создать пользователя "Достоевский Федор Михайлович" с логином DostoevskyFM, параметрами по умолчанию, диском, почтовым ящиком и доступом к Интернет:
            Create-ADUser -fullName "Достоевский Федор Михайлович" -JobTitle "Великий русский писатель" -OfficeNumber 42 -MailDatabase "Shuvoe Standard Users" -CreateOOF -InternetGroupName "web_allow_basic"
        
        .EXAMPLE
        Создать пользователя "Достоевский Федор Михайлович" с логином DostoevskyFM для московского офиса:
            Create-ADUser -fullName "Достоевский Федор Михайлович" -State "Москва" -City "Москва" -StreetAddress "4-й Добрынинский пер, 8" -FileShare "\\srvfs177\users\"

        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Authors: Khatsayuk Alexandr, Kornilov A.A.

    #>
    
    [CmdLetBinding()]
    Param (
    #region Параметры
    [switch]$Version = $false,
    # Создание учетной записи
    [ValidatePattern('^[А-ЯЁ][а-яё]+\s[А-ЯЁ][а-яё]+\s?([А-ЯЁ][а-яё]+\s?)?$')][string]$fullName,
    [ValidateSet("Егорьевск","Москва")][string]$State = "Егорьевск",
    [ValidateSet("Шувое","Москва")][string]$City = "Шувое",
    [ValidateSet("Лесная, 40","4-й Добрынинский пер, 8")][string]$StreetAddress = "Лесная, 40",
    [ValidateLength(0,64)][string]$Company = "Gedeon Richter RUS",
    [ValidatePattern('^[A-Z]{0,2}$')][string]$Country = "RU",
    [ValidateLength(0,64)][string]$JobTitle,
    [ValidatePattern('^\d{0,3}$')][int]$PhoneNumber,
    [ValidatePattern('^\d{0,4}$')][int]$OfficeNumber,
    [ValidateLength(0,64)][string]$Department,
    [ValidatePattern('^([А-Я][а-я]+\s?){3}')][string]$Manager,
    [ValidatePattern('\d{10}')][string]$employeeID = "0000000000",
    [string]$ScriptPath = "",
    [string]$OU = "OU=RGr Users,DC=Shuvoe,DC=RG-RUS,DC=RU",
    [string]$internalMessage = "<html><body>Уважаемый отправитель письма,<br>Спасибо за Ваше сообщение. Я буду отсутствовать на рабочем месте с <font color='red'>01.01.1980</font> по <font color='red'>01.04.1991</font> и буду иметь ограниченный доступ к электронной почте в данный период.<br>Я отвечу на Ваше сообщение сразу после моего возвращения.<br>Во время моего отсутствия по срочным вопросам прошу обращаться к <font color='red'>моей (моему)</font> коллеге <font color='red'>Фамилия И.О.</font> по телефону <font color='red'>640</font> или по электронной почте <font color='red'>mail@rg-rus.ru</font><br>Спасибо за понимание.<br>С уважением, <font color='red'>Фамилия И. О.</font><br><br><p>Dear Mail Sender,<br>Thank you for your mail. I will be out of the office from <font color='red'>01.01.1980</font> to <font color='red'>01.04.1991</font>. I will have limited access to my e-mail during this period.<br>I will respond to your mail as soon as possible on my return. Please note, that your mail will not be forwarded. In my absence, for any urgent matters please feel free to contact my colleague <font color='red'>Full Name</font> on <font color='red'>640</font> or e-mail <font color='red'>mail@rg-rus.ru</font><br>Thank you for your understanding.<br>Best regards, <font color='red'>Full Name</font>.</body></html>",
    [string]$externalMessage = "<html><body>Уважаемый отправитель письма,<br>Спасибо за Ваше сообщение. Я буду отсутствовать на рабочем месте с <font color='red'>01.01.1980</font> по <font color='red'>01.04.1991</font> и буду иметь ограниченный доступ к электронной почте в данный период.<br>Я отвечу на Ваше сообщение сразу после моего возвращения.<br>Во время моего отсутствия по срочным вопросам прошу обращаться к <font color='red'>моей (моему)</font> коллеге <font color='red'>Фамилия И.О.</font> по телефону <font color='red'>640</font> или по электронной почте <font color='red'>mail@rg-rus.ru</font><br>Спасибо за понимание.<br>С уважением, <font color='red'>Фамилия И. О.</font><br><br><p>Dear Mail Sender,<br>Thank you for your mail. I will be out of the office from <font color='red'>01.01.1980</font> to <font color='red'>01.04.1991</font>. I will have limited access to my e-mail during this period.<br>I will respond to your mail as soon as possible on my return. Please note, that your mail will not be forwarded. In my absence, for any urgent matters please feel free to contact my colleague <font color='red'>Full Name</font> on <font color='red'>640</font> or e-mail <font color='red'>mail@rg-rus.ru</font><br>Thank you for your understanding.<br>Best regards, <font color='red'>Full Name</font>.</body></html>",
    [string]$PDC = (Get-ADDomain).PDCEmulator,

    # Создание личного диска
    [switch]$noPersonalDrive = $false,
    [string]$fileShare = "\\fsc01\users$\",
    
    # Добавление в группу доступа к сети Интернет
    [string]$InternetGroupName,

    # Добавление в группу SD_Users (BPM'Online) - ёбаное блядство
    [switch]$noBPM = $false,

    # Создание почтового ящика
    [switch]$CreateOOF,
    [ValidateSet(
        "SHV Standard Users",
        "SHV Advanced Users",
        "Shuvoe VIP Users",
        "Moscow Standard Users",
        "Moscow Advanced Users",
        "Moscow VIP Users",
        "SHV Standard",
        "SHV Advanced"
        )][string]$MailDatabase
    )
    [string]$RetentionPolicy = "RGr Mailbox Policy"
    #endregion

    # Script version
    $VER_NUM="0.4.10.3"
    if ($version) {
        Write-Host $VER_NUM
        break
    }

    #region Генерация пароля
    function Gen-Password() {
        
        # Рандомно формируем строку для пароля
        # 5 букв из латинского алфавита в нижнем и верхнем регистре
        [string]$passChars = (Get-Random -InputObject $([char[]](97..122) + [char[]](65..90)) -Count 5) -join ''
        # 2 цифры от 0 до 9
        [string]$passNums = (Get-Random -InputObject (0..9) -Count 2) -join ''
        # 1 знак препинания
        [string]$passSymbols = (Get-Random -InputObject $([char[]]'?*%-+=!@#') -Count 1) -join ''
        # Результирующая строка
        [string]$resultPassString = $passChars + $passNums + $passSymbols

        # Конвертируем полученную строку в SecureString
        [System.Security.SecureString]$securePassword = $(ConvertTo-SecureString -AsPlainText $resultPassString -Force)
    
        # Создаем объект, содержащий как plaintext так и securestring
        $passObj = New-Object -TypeName psobject
        Add-Member -InputObject $passObj -MemberType NoteProperty -Name 'PasswordString' -Value $resultPassString
        Add-Member -InputObject $passObj -MemberType NoteProperty -Name 'SecurePasswordString' -Value $securePassword
    
        # Возвращаем сформированный объект
        return $passObj
    }

    $password = Gen-Password
    #endregion

    # Удаляем все временные сессии на CAS'ы
    Remove-PSSession -Name "Create-ADUser" -ErrorAction SilentlyContinue

    # Словарь для транслитизации
    [hashtable]$dictionary = @{ 
        [char]'а' = "a";[char]'А' = "A";
        [char]'б' = "b";[char]'Б' = "B";
        [char]'в' = "v";[char]'В' = "V";
        [char]'г' = "g";[char]'Г' = "G";
        [char]'д' = "d";[char]'Д' = "D";
        [char]'е' = "e";[char]'Е' = "E";
        [char]'ё' = "ye";[char]'Ё' = "Ye";
        [char]'ж' = "zh";[char]'Ж' = "Zh";
        [char]'з' = "z";[char]'З' = "Z";
        [char]'и' = "i";[char]'И' = "I";
        [char]'й' = "y";[char]'Й' = "Y";
        [char]'к' = "k";[char]'К' = "K";
        [char]'л' = "l";[char]'Л' = "L";
        [char]'м' = "m";[char]'М' = "M";
        [char]'н' = "n";[char]'Н' = "N";
        [char]'о' = "o";[char]'О' = "O";
        [char]'п' = "p";[char]'П' = "P";
        [char]'р' = "r";[char]'Р' = "R";
        [char]'с' = "s";[char]'С' = "S";
        [char]'т' = "t";[char]'Т' = "T";
        [char]'у' = "u";[char]'У' = "U";
        [char]'ф' = "f";[char]'Ф' = "F";
        [char]'х' = "kh";[char]'Х' = "Kh";
        [char]'ц' = "ts";[char]'Ц' = "Ts";
        [char]'ч' = "ch";[char]'Ч' = "Ch";
        [char]'ш' = "sh";[char]'Ш' = "Sh";
        [char]'щ' = "sch";[char]'Щ' = "Sch";
        [char]'ъ' = "";[char]'Ъ' = "";
        [char]'ы' = "y";[char]'Ы' = "Y";
        [char]'ь' = "";[char]'Ь' = "";
        [char]'э' = "e";[char]'Э' = "E";
        [char]'ю' = "yu";[char]'Ю' = "Yu";
        [char]'я' = "ya";[char]'Я' = "Ya";
        [char]' ' = " "
    }

    # Запишем некоторые переменные для удобочитаемости кода
    $localDomain = $env:USERDNSDOMAIN.ToLower()

    if ($fullName) {
        # Хинт - преобразуем fullName к виду "Фамилия Имя Отчество", если введено было не так.
        foreach ($Part in $fullName.Split().ToLower()) {
                $Part = $Part.Substring(0,1).ToUpper()+$Part.Substring(1)
                [array]$fullNameArray += $Part
            }
        [string]$fullName = $fullNameArray -join " "
    } else {
        Write-Host "Syntax Error: You must provide '-fullName' parameter."
        break
    }
    # Имя на транслите. Зачем? Мм, а это костыль для аппаратов Xerox, которые не могут в кириллицу. Бесит? Да, сука, бесит.
    foreach ($char in $fullName.ToCharArray()) {
        [string]$latFullName += $dictionary[$char]
    }

    # Формируем отображаемое имя специально для Валерича, в формате "Фамилия И. О." иначе WebApacs не работает.
    [string]$surName, [string]$givenName, [string]$otherName = $fullName.Split()
    if ($OtherName.Length -ne 0) { # если у вас есть отчество, значит вы россиянин
        [string]$displayName = $surName + " " + $givenName[0] + ". " + $otherName[0] + "."
        } else { # а вот иначе вы таки из гейропы и отчество будет нам мешать
            [string]$displayName = $surName + " " + $givenName
    }

    # Формируем логин пользователя в формате "FamiliyaIO"
    [string]$SecondName, [string]$FirstName, [string]$Patronymic = $LatFullName.Split()
    if ($Patronymic.length -ne 0) { # специальная проверка для гейропейцев на формирование логина
        [string]$samAccountName = $SecondName + $dictionary[$givenName[0]][0] + $dictionary[$otherName[0]][0] # Login
        } else {
            [string]$samAccountName = $SecondName + $dictionary[$givenName[0]][0] # Login
    }

    # Завершаем работу, если пользователь с таким ФИО и логином уже существует. Я бы написал обработку на изменения логина типа IOFamilia, но у нас нет соглашения на эту тему
    if (Get-ADUser -Properties DisplayName -Filter {(DisplayName -eq $displayName) -and (SamAccountName -eq $samAccountName)}) {
            Write-Host "Учетная запись с именем '$($displayName)' и логином '$($samAccountName)' уже существует!" -ForegroundColor Red
            Clear-Variable -Name DisplayName, latFullName, SamAccountName, Surname, FirstName, GivenName, OtherName, SecondName, Patronymic, fullNameArray -ErrorAction SilentlyContinue
            break
    }
    
    #region Создаем пользователя
    if ($samAccountName -ne $null) {
        #region Базовый пользователь - без отчества, инициалов, почты и пр.
        New-ADUser -SamAccountName $samAccountName `
            -Server $PDC `
            -Name $latFullName `
            -DisplayName $DisplayName `
            -ChangePasswordAtLogon $true `
            -State $State `
            -City $City `
            -StreetAddress $StreetAddress `
            -Company $Company `
            -Country $Country `
            -Title $JobTitle `
            -OfficePhone $PhoneNumber `
            -Office $OfficeNumber `
            -ScriptPath $ScriptPath `
            -Enabled $true `
            -AccountPassword $password.SecurePasswordString `
            -Surname $Surname `
            -GivenName $GivenName `
            -UserPrincipalName "$($samAccountName)@$($localDomain)" `
            -Description $fullName `
            -Department $Department `
            -Path $OU `
            -HomePage "http://intranet.$($localDomain)/sites/profiles/Person.aspx?accountname=i%3A0%23%2Ew%7Cshuvoe%5C$($samAccountName)" `
            -EmployeeID $employeeID
        #endregion "Базовый пользователь"
    
        # Если отчество было сформировано - применяем его к свежесозданной учетке и устрановим инициалы
        if ($OtherName.Length -ne 0) {
            Set-ADUser -Identity $samAccountName -Initials $($DisplayName -Replace '^\w+\s') -OtherName $OtherName -Server $PDC
        } else {
            # В обратном случае - только инициалы
            Set-ADUser -Identity $samAccountName -Initials $($GivenName[0] + ".") -Server $PDC
        }
    
        # Установка менеджера, если он был указан в параметрах
        if ($Manager.Length -gt 0) {
            [string]$mGRSurname,[string]$mGRGivenName,[string]$mGRMiddleName = $Manager.Split()
            [string]$mGRSearchFilter = '(Surname -eq $mGRSurname) -and (GivenName -eq $mGRGivenName)'
            if ($MGRMiddleName.Length -ne 0) {
                $mGRSearchFilter += ' -and (MiddleName -eq $MGRMiddleName)'
            }
            [string]$ADManagerDN = (Get-ADUser -Properties Surname,GivenName,MiddleName -Filter $mGRSearchFilter).distinguishedName
        
            Set-ADUser -Identity $samAccountName -Manager $ADManagerDN -Server $PDC
        }

        #region Обработка дополнительных параметров - личный диск, почта, интернет
        #region Создание личного диска пользователя
        if ($noPersonalDrive -eq $false) {
            try {
                # Создаем каталог для пользователя и записываем его ACL в переменную
                $PersonalDisk = New-Item -ItemType Directory -Path $($fileShare + $SamAccountName)
                $acl = Get-Acl $PersonalDisk
                # Удалим наследование
                $acl.SetAccessRuleProtection($True,$True)
                Set-Acl -Path $PersonalDisk -AclObject $acl
                # Установим разрешения для созданного пользователя
                $acl = Get-Acl $PersonalDisk
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ("$localDomain\$samAccountName","Modify","ContainerInherit,ObjectInherit","None","Allow")
                $acl.SetAccessRule($accessRule) | Out-Null
                Set-Acl -Path $PersonalDisk -AclObject $acl
            } catch [System.IO.IOException] {
                $PersonalDisk = $_.Exception.Message
            } catch [System.Exception] {
                $PersonalDisk = $_.Exception.Message
            }
        }
        #endregion

        #region Добавление в группу на доступ к Интернет
        if ($InternetGroupName.Length -ne 0) {
            try {
                Add-ADGroupMember -Identity $InternetGroupName -Members $samAccountName -Server $PDC
            } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                $InternetGroupName = $_.Exception.Message
            }
        }
        #endregion

        #region Создание почтового ящика
        if ($MailDatabase.Length -ne 0) {
            # Поиск хоста для импорта командлетов Exchange осуществяется через DNS запись autodiscover.
            $exchHost = [System.Net.Dns]::GetHostEntry("autodiscover.$($localDomain)").hostName
            # Пытаемся соединиться с ней по WMI на тот случай, если это NLB кластер.
            [string]$exchOSName = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $exchHost).CSName
            # Создаем массив командлетов для импорта с сервера
            [array]$exchCommands = "Enable-Mailbox","Set-MailboxAutoReplyConfiguration","Set-Mailbox","Get-AcceptedDomain"
            # Устанавливаем соединение
            $exchSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$($exchOSName).$($localDomain)/powershell" -Name "Create-ADUser"
            Import-PSSession -Session $exchSession -CommandName $exchCommands -ErrorAction SilentlyContinue | Out-Null
            # Получаем почтовый домен по умолчанию
            [string]$mailDomain = (Get-AcceptedDomain | Where-Object -FilterScript {$_.default -eq $true}).Name
            # Создаем ящик новому пользователю
            Enable-Mailbox -Identity "$($localDomain)\$SamAccountName" -Database $MailDatabase -RetentionPolicy "RGr Mailbox Policy" -DomainController $PDC| Out-Null
            Set-Mailbox -Identity "$($samAccountName)@$($mailDomain)" -MaxSendSize 20Mb -MaxReceiveSize 30Mb -DomainController $PDC | Out-Null
            # Если было указано - создаем автоответ
            if ($CreateOOF -eq $true) {
                Set-MailboxAutoReplyConfiguration -Identity "$($samAccountName)@$($mailDomain)" -InternalMessage $internalMessage -ExternalMessage $externalMessage -DomainController $PDC
            }
            # Удаляем сессию с CAS'ом
            Remove-PSSession -Name "Create-ADUser"
        }
        #endregion

        #region Добавление в группу SD_Users (BPMOnline)
        if ($noBPM -eq $false) {
            Add-ADGroupMember -Identity SD_Users -Members $samAccountName -ErrorAction SilentlyContinue
        }
        #endregion

    #endregion
    }
    #endregion "Создаем пользователя"
    
    # Отчет на экран
    "{0,-15}{1,-3}{2,-45}" -f "Login Name",":","$($samAccountName)"
    "{0,-15}{1,-3}{2,-45}" -f "Init Password",":",$password.PasswordString
    if ($MailDatabase.Length -ne 0) {
        "{0,-15}{1,-3}{2,-45}" -f "Email",":","$($samAccountName)@$($mailDomain)"
    }
    if ($noPersonalDrive -eq $false) {
        "{0,-15}{1,-3}{2,-45}" -f "Personal Drive",":","$($PersonalDisk.FullName)"
    }
    if ($InternetGroupName.Length -ne 0) {
        "{0,-15}{1,-3}{2,-45}" -f "Internet",":","$($InternetGroupName)"
    }
    if ($noBPM -eq $false) {
        "{0,-15}{1,-3}{2,-45}" -f "BMP'Online",":","Yes"
    }
    Clear-Variable -Name DisplayName*, trName, samAccountName, Surname, FirstName, GivenName, OtherName, SecondName, Patronymic, mGR*, exch* -ErrorAction SilentlyContinue
}
