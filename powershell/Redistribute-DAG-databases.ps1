$servername=$env:computername
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
$dagname=(Get-DatabaseAvailabilityGroup | where {$_.servers -contains $servername}).name
$partner_fqdn=[System.Net.Dns]::GetHostByName(((Get-DatabaseAvailabilityGroup $dagname).servers | where {!($_.name -eq $servername)} | select -First 1).name).Hostname
$script_dir='C:\Program Files\Microsoft\Exchange Server\V15\Scripts'
$script_redisdbs='C:\Program Files\Microsoft\Exchange Server\V15\Scripts\RedistributeActiveDatabases.ps1'
$options='-BalanceDbsByActivationPreference -Confirm:$False'

cd $script_dir
.\RedistributeActiveDatabases.ps1 -BalanceDbsByActivationPreference -Confirm:$False
