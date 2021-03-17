@ECHO ON

rem Description:    Installing Zabbix client.
rem Organization:   AO "Gedeon Richter-RUS"
rem Author:         Kornilov Alexander

IF NOT EXIST "%ProgramFiles%\Zabbix Agent" (
ECHO "Make DIR"
MD "%ProgramFiles%\Zabbix Agent"

xcopy \\fsc01\softdistrib$\zabbix_agent\latest_x64 "%ProgramFiles%\Zabbix Agent" /E /Y /Q
ECHO "Copying AGENT FILES completed"

CD "%ProgramFiles%\Zabbix Agent"
zabbix_agentd.exe --config zabbix_agentd.conf --install
ECHO "Zabbix Agent Installed"

zabbix_agentd.exe --start
ECHO "Zabbix Agent Running"

) ELSE (

ECHO "DIR is available!"
)