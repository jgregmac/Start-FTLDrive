<#
Name                      State        Function
------                    -------      ----------
Get-LocalAdministrators   Working      Enumerates all members of the local Administrators 
                                       security group
#>
[scriptblock]$block = {
    $users = @()
    #Run Net.exe to collect the membership of the local administrators group.  Exclude line that do not contain actual results:
    $users = & net.exe localgroup administrators | ? {$_ -notmatch '^Alias name |^Comment |^--|^The command|^Members$|^$'}
    #A non-zero LASTEXITCODE indicates command failure:
    if ($LASTEXITCODE -ne 0) {
        New-Object -TypeName PSCustomObject -Property @{
                computer=$env:COMPUTERNAME;
                status='failure';
                message='Failed to execute net.exe localgroup command.'
            }
    }
    write-verbose "Found users: $users"
    #A count of results greater than zero indicates success:
    if ($users.count -gt 0) {
        write-verbose "testing: $user"
        foreach ($user in $users) {
            if ($user.contains('\')) {
                write-verbose "user $user is a network user"
                $message = $user
            } elseif (& net user $user | ? {($_ -match '^Account active') -and ($_.contains('Yes'))}) {
                write-verbose "local user $user is active"
                $message = $user
            } else {
                write-verbose "local user $user is inactive"
            }
            if ($message) {
                New-Object -TypeName PSCustomObject -Property @{
                    computer=$env:COMPUTERNAME;
                    status='success';
                    message=$message
                }
                Remove-Variable message
            }
        }
    }
}
