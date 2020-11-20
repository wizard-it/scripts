@ECHO OFF
FOR /F "skip=2 tokens=2,*" %%A IN ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome" /v Version') DO (
    if exist "%ProgramFiles%\Google\Chrome\Application\%%B\Installer\setup.exe" (
        "%ProgramFiles%\Google\Chrome\Application\%%B\Installer\setup.exe" -uninstall -multi-install -chrome -system-level -force-uninstall
    )
)

FOR /F "skip=2 tokens=2,*" %%A IN ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome" /v Version') DO (
    if exist "%ProgramFiles(x86)%\Google\Chrome\Application\%%B\Installer\setup.exe" (
        "%ProgramFiles(x86)%\Google\Chrome\Application\%%B\Installer\setup.exe" -uninstall -multi-install -chrome -system-level -force-uninstall
    )
)
