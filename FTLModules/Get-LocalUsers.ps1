<#
    Name                      State        Function
    ------                    -------      ----------
    Get-LocalUsers            Working      Enumerates all active local user accounts
#>
[scriptblock]$block = {
    $cmdOut = @()
    $cmdOut = & net.exe user | ? {$_ -notmatch '^User accounts |^--|^The command|^$'}
    if ($LASTEXITCODE -gt 1) {
        New-Object -TypeName PSCustomObject -Property @{
                computer=$env:COMPUTERNAME;
                status='failure';
                message='Failed to execute "net.exe user" command.'
            }
    }
    $users = @()
    $users = $cmdOut | ForEach-Object {$_.split(' ') | ? {$_ -ne ''}}
    if ($users.count -gt 0) {
        foreach ($user in $users) {
            if (& net user $user | ? {($_ -match '^Account active') -and ($_.contains('Yes'))}) {
                write-verbose "local user $user is active."
                $message = $user
            } else {
                write-verbose "local user $user is inactive.  Excluding from reporting..."
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