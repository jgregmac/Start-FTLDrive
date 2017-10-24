function Get-MyOrgComputers {
    [cmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
            [ValidateSet('prod','test','dev')]
            [string]$scope
    )
    switch ($scope) {
        prod { 
            [string[]]$computerOUs = @(
                'OU=WinSys,OU=Information Technology Services,DC=YU,DC=YALE,DC=EDU',
                'OU=Servers,DC=YU,DC=YALE,DC=EDU',
                'OU=Exchange Servers,DC=YU,DC=YALE,DC=EDU',
                'OU=Servers,DC=YU,DC=YALE,DC=EDU'
            )
            $dom = "yu.yale.edu"
        }
        test { 
            [string[]]$computerOUs = @(
                'OU=WinSys,OU=Information Technology Services,DC=YU,DC=YALE,DC=NET',
                'OU=Servers,DC=YU,DC=YALE,DC=NET',
                'OU=Exchange Servers,DC=YU,DC=YALE,DC=NET',
                'OU=Servers,DC=YU,DC=YALE,DC=NET'
            )
            $dom = "yu.yale.net"
        }
        dev { 
            [string[]]$computerOUs = @(
                'OU=WinSys,OU=Information Technology Services,DC=YU,DC=YALE,DC=ORG',
                'OU=Servers,DC=YU,DC=YALE,DC=ORG',
                'OU=Exchange Servers,DC=YU,DC=YALE,DC=ORG',
                'OU=Servers,DC=YU,DC=YALE,DC=ORG'
            )
            $dom = "yu.yale.org"
        }
    }

    try {Import-Module ActiveDirectory -ea Stop | Out-Null} catch {
        Throw "Failed to load the Active Directory PowerShell module."
    }

    # Fetch computer objects to investigate using the OUs provided in the $ComputerOUs parameter:
    Write-Host 
    Write-Host 'Gathering Computer Objects...' -Fore Cyan
    [string[]]$computers = @()
    $lastMonth = ([datetime]::now).AddDays(-30)
    foreach ($ou in $ComputerOUs) {
        $computers += Get-ADComputer -Server $dom -SearchBase $ou `
            -Filter * -Properties OperatingSystem,OperatingSystemServicePack,OperatingSystemVersion,LastLogonTimestamp | 
            Where-Object {$_.OperatingSystem -match 'Server'} | 
            Where-Object {([datetime]::FromFileTime($_.LastLogonTimestamp)) -gt $lastMonth } |
            Select-Object -ExpandProperty Name | Sort-Object
    }
    $computers
}

Export-ModuleMember -Function Get-MyOrgComputers