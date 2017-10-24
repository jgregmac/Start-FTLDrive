[scriptblock]$block = {
    #$results = & gpupdate.exe /force 2>&1
    $results = & gpupdate.exe 2>&1
    [string]$message = ''
    if ($LASTEXITCODE -ne 0) { #a non-zero exitcode indicates failure...
        $status = 'failure'
        $message = "ReturnCode: $LastExitCode StandardOut: $results"
    } else {
        $status = 'success'
        #Send all gpupdate results to the "message" output field.
        forEach ($result in $results) {
            if ($result.length -gt 0) {
                $result.Trim()
                $message += $result
            }
        }
    }
    New-Object -TypeName PSCustomObject -ArgumentList @{
        computer=$env:COMPUTERNAME;
        status=$status;
        message=$message
    }
}