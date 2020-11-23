@ECHO OFF
if exist "%ProgramFiles%\Mozilla Firefox\uninstall\helper.exe" ("%ProgramFiles%\Mozilla Firefox\uninstall\helper.exe" /S)
if exist "%ProgramFiles(x86)%\Mozilla Firefox\uninstall\helper.exe" ("%ProgramFiles(x86)%\Mozilla Firefox\uninstall\helper.exe" /S)
for /f "delims=" %%a in ('dir/b/ad-h "C:\Users"') do (
    if exist "C:\Users\%%a\AppData\Local\Mozilla Firefox\uninstall\helper.exe" (
        "C:\Users\%%a\AppData\Local\Mozilla Firefox\uninstall\helper.exe" /S
    )
)
