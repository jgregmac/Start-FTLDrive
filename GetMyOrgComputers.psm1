<#
    SAMPLE CODE: Add your own named scoped in the "switch ($scope)" section to easily 
      collect computer objects from different OUs and domains/forests in your environment.
#>
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
                'OU=Servers,DC=NewColonial,DC=GOV',
                'OU=Exchange Servers,DC=NewColonial,DC=GOV'
            )
            $dom = "newcolonial.gov"
        }
        test { 
            [string[]]$computerOUs = @(
                'OU=Servers,DC=NewColonial-Test,DC=GOV',
                'OU=Exchange Servers,DC=NewColonial-Test,DC=GOV'
            )
            $dom = "newcolonial-test.gov"
        }
        dev { 
            [string[]]$computerOUs = @(
                'OU=Servers,DC=NewColonial-Dev,DC=GOV',
                'OU=Exchange Servers,DC=NewColonial-Dev,DC=GOV'
            )
            $dom = "newcolonial-dev.gov"
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