@ECHO OFF
if exist "%ProgramFiles%\Google\Chrome\Application" (
    FOR /F "delims=" %%e in ('dir/b/ad-h "%ProgramFiles%\Google\Chrome\Application"') do (
        if exist "%ProgramFiles%\Google\Chrome\Application\%%e\Installer\setup.exe" (
            "%ProgramFiles%\Google\Chrome\Application\%%e\Installer\setup.exe" -uninstall -multi-install -chrome -system-level -force-uninstall
        )
    )
)

if exist "%ProgramFiles(x86)%\Google\Chrome\Application" (
    FOR /F "delims=" %%d in ('dir/b/ad-h "%ProgramFiles(x86)%\Google\Chrome\Application"') do (
        if exist "%ProgramFiles(x86)%\Google\Chrome\Application\%%d\Installer\setup.exe" (
            "%ProgramFiles(x86)%\Google\Chrome\Application\%%d\Installer\setup.exe" -uninstall -multi-install -chrome -system-level -force-uninstall
        )
    )
)

FOR /f "delims=" %%c in ('dir/b/ad-h "C:\Users"') do (
    if exist "C:\Users\%%c\AppData\Local\Google\Chrome\Application" (
        FOR /F "delims=" %%g in ('dir/b/ad-h "C:\Users\%%c\AppData\Local\Google\Chrome\Application"') do (
            if exist "C:\Users\%%c\AppData\Local\Google\Chrome\Application\%%g\Installer\setup.exe" (
                "C:\Users\%%c\AppData\Local\Google\Chrome\Application\%%g\Installer\setup.exe" -uninstall -multi-install -chrome -system-level -force-uninstall
            )
        )
    )
)

@ECHO OFF
if exist "%ProgramFiles%\Mozilla Firefox\uninstall\helper.exe" ("%ProgramFiles%\Mozilla Firefox\uninstall\helper.exe" /S)
if exist "%ProgramFiles(x86)%\Mozilla Firefox\uninstall\helper.exe" ("%ProgramFiles(x86)%\Mozilla Firefox\uninstall\helper.exe" /S)
for /f "delims=" %%a in ('dir/b/ad-h "C:\Users"') do (
    if exist "C:\Users\%%a\AppData\Local\Mozilla Firefox\uninstall\helper.exe" (
        "C:\Users\%%a\AppData\Local\Mozilla Firefox\uninstall\helper.exe" /S
    )
)

@ECHO OFF
if exist “%ProgramFiles%\Opera\launcher.exe” (“%ProgramFiles%\Opera\launcher.exe” /uninstall /silent)
if exist “%ProgramFiles(x86)%\Opera\launcher.exe” (“%ProgramFiles(x86)%\Opera\launcher.exe” /uninstall /silent)
for /f "delims=" %%b in ('dir/b/ad-h "C:\Users"') do (
    if exist "C:\Users\%%b\AppData\Local\Programs\Opera\launcher.exe" (
        "C:\Users\%%b\AppData\Local\Programs\Opera\launcher.exe" /uninstall /silent
    )
)
