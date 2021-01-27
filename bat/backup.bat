@echo off
 
set source="C:\Source"
set destination="D:\Backup"
set passwd="password_archive"
set zippath="C:\Program Files\7-Zip"
set ziper="%zippath%\7z.exe"
set outdate="-7"
set start_wd="8"
set end_wd="18"

"%ziper%" a -tzip -ssw -mx5 -r0 %destination%\backup_%date%-%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%.zip %source%
forfiles /p %destination%\ /m backup_*.zip /s /d %outdate% /c "cmd /c del @path /q"
