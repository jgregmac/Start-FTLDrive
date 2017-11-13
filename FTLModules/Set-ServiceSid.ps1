<#
    Name                      State        Function
    ------                    -------      ----------
   Set-ServiceSid             Unknown      Sets the ServiceSid for the SCOM HealthService.
                                           Useful for enabling least-privilege SQL Monitoring.
#>
$block = [scriptblock]{
    $svc = 'HealthService'
    $type = 'unrestricted'

    $out = & reg.exe query HKLM\SYSTEM\CurrentControlSet\Services\HealthService /v ServiceSidType
    $lc = $LASTEXITCODE
    #Write-Host Reg query return code: $lc -ForegroundColor Yellow
    #Write-Host Reg query output: $out -ForegroundColor Yellow
    if (
        ($lc -ne 0) -or 
        ($out[2] -notmatch "ServiceSidType    REG_DWORD    0x1")
    ) {
        # Below command will set HKLM:SYSTEM\CurrentControlSet\Services\HealthService\ServiceSidType to "1"
        $out = & sc.exe sidtype $svc $type
        if ($out -eq '[SC] ChangeServiceConfig2 SUCCESS') {
            $out = Restart-Service -Name HealthService 
            Write-Host Restart of HealthService returned: $out -ForegroundColor Yellow
            #Write-Host $out -ForegroundColor Yellow
            #SUCCESS
            $status = 'success'
            $message = "Successfully set SidType to $type for $svc."
        } else {
            #FAIL
            $status = 'failure'
            $message = "Failed to set SidType to $type for $svc."
        }
        
    } else {        
        $status = 'success'
        $message = "SidType already set to $type for $svc."

    }
    New-Object -TypeName PSCustomObject -Property @{
        computer=$env:COMPUTERNAME;
        status=$status;
        message=$message
    }
}