function Update-Pkg-Choco() {
    <#
        .SYNOPSIS
        Пересобирает нугет пакет в локальную версию и выкладывает на локальный репозитарий

        .DESCRIPTION
        Функция Update-Pkg-Choco оформлена в виде командлета PowerShell и предоставляет администратору средство для автоматической пересборки пакетов с целью обновления софта из локального репозитария.

        .EXAMPLE
        Создать локальую версую пакета Zoom, в случае его отсутствия/обновления:
            Update-Pkg-Choco -pkglist zoom -repo http://nexus.shuvoe.rg-rus.ru/repository/chocolatey-hosted/ -key 349fsvsd9

        .NOTES
        Organization: AO "Gedeon Richter-RUS"
        Author: Kornilov Alexander
    #>
    param(
        [Parameter (Mandatory=$true)]
        [array]$pkglist,
        [Parameter (Mandatory=$true)]
        [string]$repo,
        [Parameter (Mandatory=$true)]
        [string]$key,
        [string]$builddir
    )

    if (!$builddir) { $builddir = [System.IO.Path]::GetTempPath() }
    $prefix = "-rg"
    $defaultRepo = "https://community.chocolatey.org/api/v2/"

    if ( -not (choco -v) ) { 
        Write-Host "Chocolatey exe problem, check application is installed. Aborting..."
        return 1
    }

    foreach ($pkgName in $pkglist) {
        
        $origPkgInfo = choco search $pkgName -e -s="$defaultRepo"
        $origPkgVer = $($($origPkgInfo | Select-String -Pattern $pkgName) -split ' ')[1]
        [int]$origPkgNumber = $origPkgVer -replace '\.',''
        $localPkgInfo = choco search $pkgName -e -s="$repo"
        if ($localPkgInfo | Select-String -Pattern $pkgName) {
            $localPkgVer = $($($localPkgInfo | Select-String -Pattern $pkgName) -split ' ')[1]
        } else {
            $localPkgVer = "0."
        }
        [int]$localPkgNumber = $localPkgVer -replace '\.',''

        if ( ($origPkgNumber -gt $localPkgNumber) -or ($origPkgNumber -eq $localPkgNumber)) {
            Write-Host "Downloading new version of $pkgName package to $builddir ..."
            Invoke-WebRequest -Uri $defaultRepo/package/$pkgName/$origPkgVer -OutFile $builddir\\$pkgName.$origPkgVer.zip
            cd $builddir
            Expand-Archive .\$pkgName.$origPkgVer.zip -Force
            cd "$pkgName.$origPkgVer"
            rmdir .\_rels -Force -Recurse
            rmdir .\package -Force -Recurse
            del *.xml
            $origScript = $origScript = Get-Content -Path .\tools\chocolateyInstall.ps1
            $origScript | Select-String -Pattern '^\$url' | Set-Content -Path .\$pkgName.vars.ps1
            . .\$pkgName.vars.ps1
            [int]$count = ($origPkgVer -split '\.').Count
            [int]$pos = $count - 2
            [int]$lastVer = ($origPkgVer -split '\.')[-1]
            $newPkgVer = (($origPkgVer -split '\.')[0..$pos] -join '.') + "." + ($lastVer + 1)
            if ($url) { $file = $($url -split '/')[-1] }
            if ($url32) { $file = $($url32 -split '/')[-1] }
            if ($url64) { $file64 = $($url64 -split '/')[-1] }
            mkdir .\tools\64 | Out-Null
            Write-Host "Downloading source files..."
            if ($url) { Invoke-WebRequest -Uri $url -OutFile tools\\$file }
            if ($url32) { Invoke-WebRequest -Uri $url32 -OutFile tools\\$file }
            if ($url64) { Invoke-WebRequest -Uri $url64 -OutFile tools\\64\\$file64 }
            $spec = Get-Content -Path .\$pkgName.nuspec
            $spec -replace "$origPkgVer","$newPkgVer" | Set-Content -Path .\$pkgName.nuspec -Force
            $origScript -replace '\$url =.*',"`$toolsDir = `"`$`(Split-Path -parent `$MyInvocation.MyCommand.Definition`)`"`r`n`$url = `"`$toolsDir\$file`"" -replace '\$url32.*',"`$toolsDir = `"`$`(Split-Path -parent `$MyInvocation.MyCommand.Definition`)`"`r`n`$url32 = `"`$toolsDir\$file`"" -replace '\$url64.*', "`$url64 = `"`$toolsDir\64\$file64`"" | Set-Content -Path .\tools\chocolateyInstall.ps1 -Force
            choco pack .\$pkgName.nuspec
            choco push -s="$repo" -k="$key" ".\$pkgName.$newPkgVer.nupkg" --force
            Write-Host "Cleaning build dir..."
            cd $builddir
            rmdir ".\$pkgName.$origPkgVer" -Recurse -Force   

        } else {
            Write-Host "Package $pkgName is up to date"
        }
    }

}