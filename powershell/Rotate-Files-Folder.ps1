function Rotate-Files-Folder() {
    <#
        .SYNOPSIS
        Удаляет файлы страше указанной даты без резервного копирования

        .DESCRIPTION
        Функция Rotate-Files-Folder оформлена в виде командлета PowerShell и предоставляет администратору средства для удаления файлов страше указанной даты, период задается в днях от текущей даты.

        .EXAMPLE
        Rotate-Files-Folder -rootPath "C:\TEMP" -days 2
        
        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Author: Kornilov Alexander

    #>
    
    [CmdLetBinding()]
    Param (
    [switch]$version,
    [Parameter (Mandatory=$true)]
    [string]$rootPath,
    [int]$days = 3
    )

    $limit = (Get-Date).AddDays(-"$days")
#    Write-Host "limit is $limit"
#    $path = $args[0]
    
    if ( -not (Test-Path -LiteralPath $rootPath -PathType Container) ) { 
        Write-Host "Root $rootPath dir is unreachable. Aborting..."
        return   
    }
    try {
        [io.file]::OpenWrite("$rootPath\pid").close()
        Remove-Item "$rootPath\pid"
    } catch {
        return "Unable to write to $rootPath. Aborting..."
    }

    # Delete files older than the $limit.
    Get-ChildItem -Path $rootPath -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force
    
    # Delete any empty directories left behind after deleting the old files.
    Get-ChildItem -Path $rootPath -Recurse -Force | Where-Object { $_.PSIsContainer -and (Get-ChildItem -Path $_.FullName -Recurse -Force | Where-Object { !$_.PSIsContainer }) -eq $null } | Remove-Item -Force -Recurse

}
