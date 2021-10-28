<#
    .SYNOPSIS
    LLD for LAN interfaces by Interface name

    .DESCRIPTION
    Retrurn JSON object for Zabbix LLD with network adapters.
    
    .PARAMETER filter
    Interface name filter. Default: "LAN"

    .PARAMETER version
    Print verion number and exit.
    
    .NOTES
    Author: Khatsayuk Alexander
    Github: https://github.com/asand3r/
#>

Param (
    [switch]$version,
    [Parameter(Position=0)][string]$part,
    [Parameter(Position=1)][switch]$pretty
)

# Script version
$VERSION_NUM="0.2"
if ($version) {
    Write-Host $VERSION_NUM
    break
}

# Low-Level Discovery function
function Make-LLD([string]$part, $pretty) {
    # Part to discover
    switch ($part) {
        "teams" {
            # Team mode and load balancing algorithm name mappings
            $teamMode = @{0 = "Static"; 1 = "SwitchIndepenent"; 2 = "Lacp"}
            $teamLBAlg = @{0 = "TransportPorts"; 2 = "IPAddresses"; 3 = "MacAddresses"; 4 = "HyperVPort"; 5 = "Dynamic"}
    
            $netTeams = Get-WmiObject -Namespace ROOT\StandardCimv2 -Class MSFT_NetLbfoTeam
            $lldData = $netTeams | Select-Object @{Name = "{#TEAM.NAME}"; expression = {$_.Name}},
                                                 @{Name = "{#TEAM.MODE}"; expression = {$_.TeamingMode}},
                                                 @{Name = "{#TEAM.ALG}"; expression = {$_.LoadBalancingAlgorithm}},
                                                 @{Name = "{#TEAM.MODENAME}"; expression = {$teamMode[[int]$_.TeamingMode]}},
                                                 @{Name = "{#TEAM.ALGNAME}"; expression = {$teamLBAlg[[int]$_.LoadBalancingAlgorithm]}}
        
        }
        "members" {
            $teamMembers = Get-WmiObject -Namespace ROOT\StandardCimv2 -Class MSFT_NetLbfoTeamMember

            $lldData = $teamMembers | Select-Object @{Name = "{#IF.NAME}"; expression = {$_.Name}},
                                                    @{Name = "{#IF.TEAM}"; expression = {$_.Team}},
                                                    @{Name = "{#IF.DESCRIPTION}"; expression = {$_.InterfaceDescription}}
        }                                            
        default { Write-Host "ERROR: Provide a correct part name: 'teams' or 'members'."; exit 1}
    }
    
    # Output
    if ($pretty) {
        ConvertTo-Json -InputObject @{"data" = $lldData}
    } else {
        ConvertTo-Json -InputObject @{"data" = $lldData} -Compress
    }
}

Make-LLD -part $part -pretty $pretty