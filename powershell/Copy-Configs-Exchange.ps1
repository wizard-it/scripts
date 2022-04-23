# Setup source and destination paths
$Src = 'C:\Program Files\Microsoft\Exchange Server\V15\ClientAccess'
$Dst = 'F:\bkp'

# Wildcard for filter
$Extension = '*.config'

# Get file objects recursively
Get-ChildItem -Path $Src -Filter $Extension -Recurse |
    # Skip directories, because XXXReadMe.txt is a valid directory name
    Where-Object {!$_.PsIsContainer} |
        # For each file
        ForEach-Object {

            # If file exist in destination folder, rename it with directory tag
            if(Test-Path -Path (Join-Path -Path $Dst -ChildPath $_.Name))
            {
                # Get full path to the file without drive letter and replace `\` with '-'
                # [regex]::Escape is needed because -replace uses regex, so we should escape '\'
                $NameWithDirTag = (Split-Path -Path $_.FullName -NoQualifier)  -replace [regex]::Escape('\'), '-'

                # Join new file name with destination directory
                $NewPath = Join-Path -Path $Dst -ChildPath $NameWithDirTag
            }
            # Don't modify new file path, if file doesn't exist in target dir
            else
            {
                $NewPath = $Dst
            }

            # Copy file
            Copy-Item -Path $_.FullName -Destination $NewPath
        }