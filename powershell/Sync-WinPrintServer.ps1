$ProgramPath = 'C:\Windows\System32\Spool\Tools\PrintBrm.exe'
$LogPath = C:\Scripts
$ArchiveName1 = 'print-backup-log'
$ArchiveName2 = 'print-restore-log'

$SourceServer = 'shv-vprn01'
$DestServer = 'shv-vprn02'

$ConfigFilePath = 'C:\Scripts\prn-config.printerExport'

$Arguments = "-B -S $SourceServer -F $ConfigFilePath"
Start-process $ProgramPath -ArgumentList $Arguments -Wait -RedirectStandardOutput "$LogPath\$ArchiveName1.txt"

$Arguments = "-R -S $DestServer -F $ConfigFilePath"
Start-process $ProgramPath -ArgumentList $Arguments -Wait -RedirectStandardOutput "$LogPath\$ArchiveName2.txt"

Del $ConfigFilePath