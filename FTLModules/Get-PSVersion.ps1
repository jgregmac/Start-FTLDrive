[scriptblock]$block = {
    $message = $PSVersionTable.PSVersion.ToString()
    New-Object -TypeName PSCustomObject -Property @{
        computer=$env:COMPUTERNAME;
        status='success';
        message=$message
    }
}