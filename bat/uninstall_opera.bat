@ECHO OFF
for /f "delims=" %%a in ('dir/b/ad-h "C:\Users"') do (
    if exist "C:\Users\%%a\AppData\Local\Programs\Opera\launcher.exe" (
        "C:\Users\%%a\AppData\Local\Programs\Opera\launcher.exe" /uninstall /silent
    )
)
if exist “%ProgramFiles%\Opera\launcher.exe” (“%ProgramFiles%\Opera\launcher.exe” /uninstall /silent)
if exist “%ProgramFiles(x86)%\Opera\launcher.exe” (“%ProgramFiles(x86)%\Opera\launcher.exe” /uninstall /silent)
