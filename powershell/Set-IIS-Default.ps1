# Set IIS Default settings for all sites 
# Organization: AO "Gedeon Richter-RUS"
# Author: Kornilov Alexander

# Vars
$logFields = "Date,Time,ClientIP,UserName,ServerIP,Method,UriStem,UriQuery,HttpStatus,Win32Status,TimeTaken,ServerPort,UserAgent,Referer,Host,HttpSubStatus"


# Body
# Load snapins etc

Import-Module -Name WebAdministration

# Set Logging settings

Get-ChildItem -Path 'IIS:\Sites\' | Set-ItemProperty -Name logfile.logExtFileFlags -Value $logFields

