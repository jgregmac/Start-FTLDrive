<#
    Name                      State        Function
    ------                    -------      ----------
    Restart-HealthService     Partial      Restarts the SCOM Health Service if it is hung.  Success
                                           reporting may not be working properyly.
#>
[scriptblock]$block = {
    if ((get-service healthservice).status  -eq 'StartPending') {
        $results = & taskkill /IM HealthService.exe /F 2>&1
        $rc = $LASTEXITCODE
        if ($rc -ne 0) {
            $status = 'failure'
            $message = "ReturnCode: $rc StandardOut: $results"
        }
        try {
            Start-Service healthservice -ErrorAction Stop | Out-Null
        } catch {
            $status = 'failure'
            $message = "Failed to start HealthService"
        }
        $status = 'success'
        $message = "HealthService started successfully."
    }
    New-Object -TypeName PSCustomObject -ArgumentList @{computer=$env:COMPUTERNAME;status=$status;message=$message}
}