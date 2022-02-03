@echo off

rem Description:    Start application from current dir if some file exist
rem Organization:   AO "Gedeon Richter-RUS"
rem Author:         Kornilov Alexander

if exist "%USERPROFILE%\AppData\Local\Microsoft\Teams\Update.exe" ("%~dp0Teams.exe" -s)

