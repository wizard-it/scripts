#requires -version 2
<#
.SYNOPSIS
Cleanup_ShadowRedundancyQueue.ps1 - Exchange Server 2010 script to cleanup shadow redunancy queues

.DESCRIPTION 
Performs a search per server per shadow redundancy queue. If shadow redundancy queues contain
at least 1 message the receive date is inspected. If it is more then 1 day ago it will cleanup
the message.

Normally you do not have to cleanup the shadow redundancy queues because messages will automatically
expire in 2 days by default. However in some scenarios it might be necessary to clean the queues

.OUTPUTS
If messages where found which can be deleted it will tell you how many messages are
found per shadow redundanct queue.
If no messages where found you will also be informed about it

.PARAMETER server
The server for which the script needs to investigate the shadow redundancy queues


.EXAMPLE
.\Cleanup_ShadowRedundancyQueue.ps1 -server EHT01
Searches the shadow redundancy queues on server EHT01.

.LINK

.NOTES
Written By: Johan Veldhuis
Website:	http://www.johanveldhuis.nl
Twitter:	http://twitter.com/jveldh

Change Log

V1.0, 20/06/2013 - Initial version
#>

Param(
[Parameter(Mandatory=$True)]
[string]$server
)

#...................................
# Initialize
#...................................
$queues = @()
$messages = @()
$currentdate =  (get-date(get-date -Format G)).AddDays(-1)

#...................................
# Script
#...................................
#Get shadow redundancy queues which are on the server
$queues = get-queue -server $server|where {$_.DeliveryType -eq "ShadowRedundancy" -AND $_.MessageCount -gt "0" }

#Find messages in the shadow redundancy that are older then one day and remove them without confirmation
Foreach ($queue in $queues){
								$messages = @(get-message -queue $queue.Identity|where {$_.DateReceived -lt $currentdate}|select Identity)
								
								if ($messages -ne $null){											
														Write-Host "Messages found in queue" $queue.identity":" $messages.count -ForegroundColor Red
														Foreach ($message in $messages){
																 remove-message -identity $message.Identity -WithNDR $false -Confirm:$False
															}
														Write-Host "Cleanup of shadow redundancy queue" $queue.identity "completed" -ForegroundColor Green
														Write-Host ""
														}
								else{
										Write-Host "No messages where found to cleanup in shadow redundancy queue" $queue.identity -ForegroundColor Green
										Write-Host ""
									}
							}
							