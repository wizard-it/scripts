function Lock-File() {
    <#
        .SYNOPSIS
        Выставляет ACL на указанный файл

        .DESCRIPTION
        Функция Lock-File оформлена в виде командлета PowerShell и предоставляет администратору средство для блокирования доступа к файлу путем изменения ACL файла с возможностью обратного действия.

        .EXAMPLE
        Lock-File -path "H:\Обмен\test.txt"
        Lock-File -path "H:\Обмен\test.txt" -trustList @{"MYSERVER\Administrators","MYDOMAIN\Administrators"} -accessList @{"MYDOMAIN\Administrators"}
        Lock-File -path "H:\Обмен\test.txt" -recover
        
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
    [string]$path,
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
        $tShortName = $target.Split('\')[-1]
        $tPath = Split-Path -Path $target -Resolve
        $storeFullName = $tPath + "\" + "." + $tShortName + ".acl.xml" 
        $tAcl | Export-Clixml -Path $storeFullName
    }

    function restoreAcl {
        param (
        [Parameter (Mandatory=$true)]
        [string]$target
        )
        $tShortName = $target.Split('\')[-1]
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
                if ($trace) {Write-Host "[INFO] Removing access for $($rule.IdentityReference)"}
                $tAcl.RemoveAccessRule($rule) | Out-Null
            }
        }
        foreach ($account in $accessList) {
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($account,"FullControl","Allow")
            if ($trace) {Write-Host "[INFO] Adding access for $account"}
            $tAcl.SetAccessRule($accessRule)
        }
        Set-Acl -Path $target -AclObject $tAcl
    }

    if (!$trace) {$ErrorActionPreference = 'silentlycontinue'}
    $fPath = $(Resolve-Path -Path $path).Path
    if ($fPath.Split('\')[0] -eq 'Microsoft.PowerShell.Core') {
        $path = '\' + $($fPath.Split('\')[2..$fPath.Split('\').Count] -join '\')
    } else {
        $path = $fPath
    }
    if ($trace) {Write-Host "[INFO] Checking permission..."}
# Check basic permissions
    if ( -not (Test-Path -LiteralPath $path -PathType Leaf) ) { 
        Write-Host "File $path not found. Aborting..."
        return 1
    }
    try {
        [io.file]::OpenWrite($path).close()
    } catch {
        Write-Host "Unable to write to file $path. Aborting..."
        return 1
    }
    if ($trace) {Write-Host "[INFO] Set defaults..."}
# Set default access and trust lists (if not defined)
    if (!$accessUsers) {$accessUsers = @("SHUVOE\KornilovAA", "SHUVOE\PiskunovDV","SHUVOE\Администраторы домена")}
    if (!$trustUsers) {$trustUsers = @("BUILTIN\Администраторы", "NT AUTHORITY\СИСТЕМА", "SHUVOE\Администраторы домена")}
# Recovering (unlocking) ACL
    if ($recover) {
        if ($trace) {Write-Host "[INFO] Restoring permissions to file..."}
        restoreAcl -target $path
        return 0
    }
# Save origin ACL
    if ($trace) {Write-Host "[INFO] Backuping ACL..."}
    backupAcl -target $path
# Disable parents
    if ($trace) {Write-Host "[INFO] Disabling parent's access..."}
    disableInherited -target $path
# Locking file
    if ($trace) {Write-Host "[INFO] Locking file (changing ACL)..."}
    lockFile -target $path -trustList $trustUsers -accessList $accessUsers
}
