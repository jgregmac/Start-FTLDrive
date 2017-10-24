$localHeaders = @('ports','registry')

[scriptblock]$block = {
    #Collect list of listenting ports for Intel AMT engine:
    [array]$hits +=  & netstat -na | Select-String -Pattern ":(16993|16992|16994|16995|623|664) " | ForEach-Object {$_.matches[0].groups[1].value }
    #Convert the collected ports to string:
    if ($hits.count -gt 0) {
        $ports = [string]$hits
    } else {
        $ports = 'null'
    }

    #Check for known registry value used by Intel AMT:
    if (
        (Get-ChildItem "HKLM\SOFTWARE\Intel\Setup and Configuration Software\SystemDiscovery" -ErrorAction SilentlyContinue) -or
        (Get-ChildItem "HKLM\SOFTWARE\Wow6432Node\Intel\Setup and Configuration Software\SystemDiscovery" -ErrorAction SilentlyContinue)
    ) {
        #Write-Host "  Found registry value indicating Intel AMT is installed on $env:Computername" -ForegroundColor Cyan
        $reg = $true
    } else {
        $reg = $false
    }

    #Report back to the calling process:
    if (($hits.count -gt 0) -or $reg) {
        New-Object -TypeName pscustomobject -Property @{
            computer=$env:Computername;
            status='success';
            ports=$ports;
            registry=[string]$reg;
            message="Intel AMT Detected."
        }
    } else {
        #Write-Host "  Intel AMT engine not found on host $env:Computername" -ForegroundColor Gray
        New-Object -TypeName pscustomobject -Property @{
            computer=$env:Computername;
            status='success';
            ports=$null;
            registry=$null;
            message="Intel AMT Engine not detected."
        }
    }
}