function Lock-File() {
    <#
        .SYNOPSIS
        Выставляет ACL на указанный файл

        .DESCRIPTION
        Функция Lock-File оформлена в виде командлета PowerShell и предоставляет администратору средство для блокирования доступа к файлу путем изменения ACL файла с возможностью обратного действия.

        .EXAMPLE
        Lock-File -file "H:\Обмен\test.txt"
        Lock-File -file "H:\Обмен\test.txt" -trustList @{"MYSERVER\Administrators","MYDOMAIN\Administrators"} -accessList @{"MYDOMAIN\Administrators"}
        Lock-File -file "H:\Обмен\test.txt" -recover
        
        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Author: Kornilov Alexander

    #>
    
    [CmdLetBinding()]
    Param (
    [switch]$version,
    [switch]$trace,
    [switch]$recover,
    [Parameter (Mandatory=$true)]
    [string]$file,
    [array]$trustUsers,
    [array]$accessUsers
    )

    function disableInherited {
        param (
        [Parameter (Mandatory=$true)]
        [string]$target
        )
        $tAcl = Get-Acl -Path $target
        $tAcl.SetAccessRuleProtection($true,$true)
        Set-Acl -Path $target -AclObject $tAcl
    }
    function backupAcl {
        param (
        [Parameter (Mandatory=$true)]
        [string]$target
        )
        $tAcl = Get-Acl -Path $target
        $tShortName = Get-ChildItem -Path $target -Name
        $tPath = Split-Path -Path $target -Resolve
        $storeFullName = $tPath + "\" + "." + $tShortName + ".acl.xml" 
        $tAcl | Export-Clixml -Path $storeFullName
    }

    function restoreAcl {
        param (
        [Parameter (Mandatory=$true)]
        [string]$target
        )
        $tShortName = Get-ChildItem -Path $target -Name
        $tPath = Split-Path -Path $target -Resolve
        $storeFullName = $tPath + "\" + "." + $tShortName + ".acl.xml"
        if ( -not (Test-Path -LiteralPath $storeFullName -PathType Leaf) ) {
            Write-Host "Can't find ACL file. Aborting restore function..."
            return 1
        }
        $tAcl = Import-Clixml -Path $storeFullName
        Set-Acl -Path $target -AclObject $tAcl
    }

    function lockFile {
        param (
        [Parameter (Mandatory=$true)]
        [string]$target,
        [Parameter (Mandatory=$true)]
        [array]$trustList,
        [Parameter (Mandatory=$true)]
        [array]$accessList
        )
        $tAcl = Get-Acl -Path $target
        foreach ($rule in $tAcl.Access) {
            if ( -not ($rule.IdentityReference.Value -in $trustList) ) {
                $tAcl.RemoveAccessRule($rule) | Out-Null
            }
        }
        foreach ($account in $accessList) {
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($account,"FullControl","Allow")
            $tAcl.SetAccessRule($accessRule)
        }
        Set-Acl -Path $target -AclObject $tAcl
    }

    if ($trace) {Write-Host "[INFO] Checking permission..."}
# Check basic permissions
    if ( -not (Test-Path -LiteralPath $file -PathType Leaf) ) { 
        Write-Host "File $file not found. Aborting..."
        return 1
    }
    try {
        [io.file]::OpenWrite($file).close()
    } catch {
        Write-Host "Unable to write to file $file. Aborting..."
        return 1
    }
    if ($trace) {Write-Host "[INFO] Set defaults..."}
# Set default access and trust lists (if not defined)
    if (!$accessUsers) {$accessUsers = @("SHUVOE\KornilovAA", "SHUVOE\PiskunovDV","SHUVOE\Администраторы домена")}
    if (!$trustUsers) {$trustUsers = @("BUILTIN\Администраторы", "NT AUTHORITY\СИСТЕМА", "SHUVOE\Администраторы домена")}
# Recovering (unlocking) ACL
    if ($recover) {
        if ($trace) {Write-Host "[INFO] Restoring permissions to file..."}
        restoreAcl -target $file
        return 0
    }
# Save origin ACL
    if ($trace) {Write-Host "[INFO] Backuping ACL..."}
    backupAcl -target $file
# Disable parents
    if ($trace) {Write-Host "[INFO] Disabling parent's access..."}
    disableInherited -target $file
# Locking file
    if ($trace) {Write-Host "[INFO] Locking file (changing ACL)..."}
    lockFile -target $file -trustList $trustUsers -accessList $accessUsers
}
