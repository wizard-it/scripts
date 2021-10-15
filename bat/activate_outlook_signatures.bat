@echo off

rem Description:    Delete regedit keys that blocked Outlook sigs
rem Organization:   AO "Gedeon Richter-RUS"
rem Author:         Kornilov Alexander

reg delete HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Outlook\Setup /v First-Run /f