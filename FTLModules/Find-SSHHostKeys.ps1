<#
    Name                      State        Function
    ------                    -------      ----------
    Find-SSHHostKeys          Working      Detects the presence of PuTTY SSHHostKeys registry 
                                           values on all local users.
#>

$localHeaders = @('sid','keys')

[scriptblock]$block = {
    # Currently this script returns nothing other than host output if no keys are found.
    # Is that desirable?
    Write-Host "Searching for SSH Host keys on: $env:Computername" -ForegroundColor White

    [pscustomobject[]]$localKeys = @()

    function get-regValues {
        param ([string]$regKey)
        $values = & reg.exe query $regKey 2> $null
        if ($LASTEXITCODE -ne 0) {
            throw "  Registry values not found for $regkey"
        } else {
            return $values
        }
    }

    #Find the SIDs for all profiles on this computer:
    [string[]]$profSids = reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | %{$_.split('\')} | select-string -pattern '^S-1-5-'
    #Find the SIDs for all profiles currently loaded in HKEY_USERS:
    [string[]]$loadSids = reg query HKU | %{$_.split('\')} | select-string -pattern '^S-1-5-'

    foreach ($sid in $profSids) {
        # Test to see if the SID is loaded:
        # (Do not use the '-in' comparison operator... it is not supported on earlier versions of PowerShell.  Instead use '-contains'.
        if ($loadSids -contains $sid) {
            [string]$sshPath = 'HKU\' + $sid + '\SOFTWARE\SimonTatham\PuTTY\SshHostKeys'
            try {
                #Capture SSH keys if present:
                [array]$keys = get-regValues -regKey $sshPath
            } catch {
                write-host "  SSH Host Keys not found for $sid in online registry" -ForegroundColor Gray
            }
            if ($keys.count -gt 0) {
                write-host "    Found Host keys for $sid in online registry: $keys" -ForegroundColor Cyan
                $localKeys += New-Object pscustomobject -Property @{computer=$env:Computername;status='success';sid=$sid;keys=$keys}
            }
        } else {
            #If the NTUSER.DAT registry hive for the profile user is not loaded, we will need to load it.

            #Find the NTUSER.DAT file for the SID:
            [string]$profPath = & reg.exe query (‘HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\’ + $sid)  /v ProfileImagePath 2> $null | %{$_.split(' ')} | select-string -Pattern '^[A-Z]:\\'
            $hivePath = Join-Path -Path $profPath -ChildPath 'NTUSER.DAT'
            $tempHive = "HKLM\sshHostKeyTemp"
            
            if (test-path $hivePath) {
                #Test to see if the tempHive is loaded:
                & reg.exe query $tempHive 2> $null
                if ($LASTEXITCODE -ne 1) {
                    #Attempt to unload the tempHive
                    & reg.exe unload $tempHive 2> $null | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        #Fail if the tempHive cannot be unloaded.
                        $localKeys += New-Object pscustomobject -Property @{computer=$env:computername;status='failure';message="Failed to unload $tempHive on $env:Computername"}
                        exit
                    }
                }
                #Load the NTUSER.DAT into the tempHive:
                & reg.exe load $tempHive $hivePath 2> $null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    #Capture the SSH host keys if present:
                    [string]$sshPath = 'HKU\' + $sid + '\SOFTWARE\SimonTatham\PuTTY\SshHostKeys'
                    try {
                        [array]$keys = get-regValues -regKey $sshPath
                    } catch {
                        write-host "  SSH Host Keys not found for $sid" -ForegroundColor Gray
                    }
                    if ($keys.count -gt 0) {
                        write-host "  Found Host keys for $sid in offline registry: $keys" -ForegroundColor Cyan
                        $localKeys += New-Object pscustomobject -Property @{computer=$env:Computername;status='success';sid=$sid;keys=$keys}
                    }
                }
                #Unload the NTUSER.DAT from the tempHive:
                & reg.exe unload $tempHive 2> $null | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    #Fail if the tempHive cannot be unloaded:
                    $localKeys += New-Object pscustomobject -Property @{computer=$env:computername;status='failure';message="Failed to unload $tempHive for $sid on $env:Computername"}
                    exit
                }
            } else {
                Write-Host "  User with $sid does not have an NTUSER.DAT file on $env:computername" -ForegroundColor Gray
            }
        }
    }
    if ($localKeys.count -gt 0) {
        $localKeys
    }
}