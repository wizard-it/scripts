@echo off

rem Description:    Sync files from servers, remote folders etc.
rem Organization:   AO "Gedeon Richter-RUS"
rem Author:         Kornilov Alexander

cd %WINDIR%\system32  
robocopy \\fsc01\softdistrib$\WindowsPowerShell %USERPROFILE%\Documents\WindowsPowerShell /mir /z /e /R:1 /W:10 /mt:2