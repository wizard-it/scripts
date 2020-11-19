@ECHO OFF
FOR /F "skip=2 tokens=2,*" %%A IN ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome" /v Version') DO set "CHROMEVER=%%B"
"C:\Program Files\Google\Chrome\Application\%CHROMEVER%\Installer\setup.exe" -uninstall -multi-install -chrome -system-level -force-uninstall

FOR /F "skip=2 tokens=2,*" %%A IN ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome" /v Version') DO set "CHROMEVER=%%B"
"C:\Program Files (x86)\Google\Chrome\Application\%CHROMEVER%\Installer\setup.exe" -uninstall -multi-install -chrome -system-level -force-uninstall
