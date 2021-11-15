function Update-Pkg-Choco() {
    <#
        .SYNOPSIS
        Пересобирает NuGet пакет в локальную версию и выкладывает на локальный репозитарий

        .DESCRIPTION
        Функция Update-Pkg-Choco оформлена в виде командлета PowerShell и предоставляет администратору средство для автоматической пересборки пакетов NuGet с целью обновления софта из локального репозитария.

        .EXAMPLE
        Создать локальую версую пакета Zoom, в случае его отсутствия/обновления:
            Update-Pkg-Choco -pkglist zoom -repo http://nexus.shuvoe.rg-rus.ru/repository/chocolatey-hosted/ -key 65461b1d-1c11-3938

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
        [switch]$save,
        [string]$builddir = [System.IO.Path]::GetTempPath()
    )

    function rebuildPkg {
        param (
            [string]$pkgName,
            [string]$localRepo,
            [string]$localKey,
            [string]$workDir
        )
        cd $workDir
        $defaultRepo = "https://community.chocolatey.org/api/v2/"
        $origPkgInfo = choco search $pkgName -e -s="$defaultRepo"
        $origPkgVer = $($($origPkgInfo | Select-String -Pattern $pkgName) -split ' ')[1]
        [int]$origPkgNumber = $origPkgVer -replace '\.',''
        $localPkgInfo = choco search $pkgName -e -s="$localRepo"
        if ($localPkgInfo | Select-String -Pattern $pkgName) {
            $localPkgVer = $($($localPkgInfo | Select-String -Pattern $pkgName) -split ' ')[1]
        } else {
            $localPkgVer = "0."
        }
        [int]$localPkgNumber = $localPkgVer -replace '\.',''
        if ( ($origPkgNumber -gt $localPkgNumber) -or ($origPkgNumber -eq $localPkgNumber)) {
            Write-Host "Downloading new version of $pkgName package to $workDir ..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $defaultRepo/package/$pkgName/$origPkgVer -OutFile $workDir\$pkgName.zip
            Expand-Archive $workDir\$pkgName.zip -Force
            rmdir $workDir\$pkgName\_rels -Force -Recurse
            rmdir $workDir\$pkgName\package -Force -Recurse
            del $workDir\$pkgName\*.xml
            [int]$count = ($origPkgVer -split '\.').Count
            [int]$pos = $count - 2
            [int]$lastVer = ($origPkgVer -split '\.')[-1]
            $newPkgVer = (($origPkgVer -split '\.')[0..$pos] -join '.') + "." + ($lastVer + 1)
            $origSpec = Get-Content -Path $workDir\$pkgName\$pkgName.nuspec
            $origSpec -replace "<version>$origPkgVer","<version>$newPkgVer" | Set-Content -Path $workDir\$pkgName\$pkgName.nuspec -Force
            $matchDep = Select-String -Path $workDir\$pkgName\$pkgName.nuspec -Pattern "dependency id"
            if ($matchDep) {
                foreach ($str in $matchDep) {
                    $pool = $str -split '\s+'
                    $depName = $pool[2] -replace 'id=|\"',''
                    $origDepVer = $pool[3] -replace 'version=|\"|\[|\]',''
                    $origSpec = Get-Content -Path $workDir\$pkgName\$pkgName.nuspec
                    $newSpec = "$workDir\$pkgName\$pkgName.nuspec.new"
                    [int]$count = ($origDepVer -split '\.').Count
                    [int]$pos = $count - 2
                    [int]$lastOrigDepVer = ($origDepVer -split '\.')[-1]
                    $newDepVer = (($origDepVer -split '\.')[0..$pos] -join '.') + "." + ($lastOrigDepVer + 1)
                    foreach ($specstr in $origSpec) {
                        if ($specstr -match "<dependency id=`"$depName") {
                            $newspecstr = $specstr -replace $origDepVer, $newDepVer
                            Add-content -Path $newSpec -value $newspecstr
                        } else {
                            Add-content -Path $newSpec -value $specstr
                        }
                    }
                    Move-Item -Path $workDir\$pkgName\$pkgName.nuspec -Destination $workDir\$pkgName\$pkgName.nuspec.old
                    Copy-Item -Path $workDir\$pkgName\$pkgName.nuspec.new -Destination $workDir\$pkgName\$pkgName.nuspec
                    rebuildPkg -pkgName $depName -origPkgVer $origDepVer -workDir $workDir
                }
            }
            $origScript = $origScript = Get-Content -Path $workDir\$pkgName\tools\chocolateyInstall.ps1
            $origScript | Select-String -Pattern '^\$url' | Set-Content -Path $workDir\$pkgName\$pkgName.vars.ps1
            . $workDir\$pkgName\$pkgName.vars.ps1
            if ($url) { $file = $($url -split '/')[-1] }
            if ($url32) { $file = $($url32 -split '/')[-1] }
            if ($url64) { $file64 = $($url64 -split '/')[-1] }        
            mkdir $workDir\$pkgName\tools\64 | Out-Null
            Write-Host "Downloading source files..."
            if ($url) { Invoke-WebRequest -Uri $url -OutFile $workDir\$pkgName\tools\$file }
            if ($url32) { Invoke-WebRequest -Uri $url32 -OutFile $workDir\$pkgName\tools\$file }
            if ($url64) { Invoke-WebRequest -Uri $url64 -OutFile $workDir\$pkgName\tools\64\$file64 }
            $origScript -replace '^\$ErrorAction.*',"`$toolsDir = `"`$`(Split-Path -parent `$MyInvocation.MyCommand.Definition`)`"`r`n`$ErrorActionPreference = `'Stop`'" -replace '^\$url =.*',"`$url = `"`$toolsDir\$file`"" -replace '^\$url32.*',"`$url32 = `"`$toolsDir\$file`"" -replace '^\$url64.*', "`$url64 = `"`$toolsDir\64\$file64`"" | Set-Content -Path $workDir\$pkgName\tools\chocolateyInstall.ps1 -Force
            Write-Host "Building pkg $pkgName version $newPkgVer, old version is $origPkgVer in dir $workDir\$pkgName"
            choco pack $workDir\$pkgName\$pkgName.nuspec       
            choco push -s="$localRepo" -k="$localKey" "$workDir\$pkgName.$newPkgVer.nupkg" --force
            Write-Host "Cleaning build dir..."
            rmdir "$workDir\$pkgName" -Recurse -Force
            del "$workDir\$pkgName.zip"
            if (!$save) { del $workDir\$pkgName.$newPkgVer.nupkg }
        } else {
            Write-Host "Package $pkgName is up to date"
        }
    }

    if ( -not (choco -v) ) { 
        Write-Host "Chocolatey exe problem, check application is installed. Aborting..."
        return 1
    }

    foreach ($name in $pkglist) {
        rebuildPkg -pkgName $name -localRepo $repo -localKey $key -workDir $builddir
    }
}