$servername=$env:computername
$dagname=(Get-DatabaseAvailabilityGroup | where {$_.servers -contains $servername}).name
$partner_fqdn=[System.Net.Dns]::GetHostByName(((Get-DatabaseAvailabilityGroup $dagname).servers | where {!($_.name -eq $servername)} | select -First 1).name).Hostname

if($args[1] -eq "drain"){
 if((get-exchangeserver $servername).serverrole -match "Mailbox"){
  Set-ServerComponentState $servername -Component HubTransport -State Draining -Requester Maintenance
  Redirect-Message -Server $servername -Target $partner_fqdn -Confirm:$false
  Suspend-ClusterNode $servername
  Set-MailboxServer $servername -DatabaseCopyActivationDisabledAndMoveNow $True
  Set-MailboxServer $servername -DatabaseCopyAutoActivationPolicy Blocked
 }
 Set-ServerComponentState $servername -Component ServerWideOffline -State inactive -Requester Maintenance
}
else{
 Set-ServerComponentState $servername -Component ServerWideOffline -State Active -Requester Maintenance
 if((get-exchangeserver $servername).serverrole -match "Mailbox"){
  Resume-ClusterNode $servername
  Set-MailboxServer $servername -DatabaseCopyActivationDisabledAndMoveNow $False
  Set-MailboxServer $servername -DatabaseCopyAutoActivationPolicy Unrestricted
  Set-ServerComponentState $servername -Component HubTransport -State Active -Requester Maintenance
 }
}
