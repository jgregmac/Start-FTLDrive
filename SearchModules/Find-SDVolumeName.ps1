$localHeaders = @('SDPresent','VolumeName','StorageSystem','MountPoints')
[scriptblock]$block = {
    #The NetApp PowerShell module does not want to load in a remote session.  Boo!
    #Instead we must use SDCli.exe.

    #Path to SDCli.exe:
    $SDCliPath = "C:\Program Files\NetApp\SnapDrive\SDCli.exe"
    
    if (Test-Path $SDCliPath) {
        #SDCli is present... let's run it:
        $SDOut = & $SDCliPath disk list
        $rc = $LASTEXITCODE
        if ($LASTEXITCODE -ne 0) {
            #SDCli returned a non-zero error code.  Report an execution failure:
            New-Object -TypeName PSCustomObject -Property @{
                computer=$env:COMPUTERNAME;
                status='failure';
                message="SDCli.exe returned a non-zero exit code: $rc";
                SDPresent='true';
            }
        } else {
            #SDCli Ran successfully, let's parse the output:
            #Capture all "Storage System Path:" entries from SDCli output, convert to semi-colon separated string:
            $pathArray = $SDOut | Select-String 'Storage System Path:' |                      #Get the whole matching line
                 ForEach-Object {($_.tostring().split(':') | Select-Object -last 1).Trim()} | #Get the path value
                 ForEach-Object {$_.split('/') | Select-Object -Last 1}                       #Capture the end of the path
            [string]$volNames = ''
            $pathArray | ForEach-Object {$volNames += $_ + ';'}
            $volNames = $volNames.TrimEnd(';')

            #Capture just the first "Storage System:" entry in SDCli output:
            $storSystem = (
                    (($SDOut | Select-String 'Storage System:') | Select-Object -First 1).toString().Split(':') | 
                    Select-Object -last 1
                ).Trim()
            
            #Capture the mount points from SDCli.exe output:
            [string]$MPs = ''
            $SDOut | Select-String 'Mount Points:' | 
                ForEach-Object {
                    $mpLine = $_.tostring()
                    $pos = $MPLine.IndexOf(':')
                    $MPs += ($MPLine.Substring($pos+1).Trim() + ';')
                }
            $MPs = $MPs.TrimEnd(';')
            
            #Emit all captured info as a PSCustomObject:
            New-Object -TypeName PSCustomObject -Property @{
                computer      = $env:COMPUTERNAME;
                status        = 'success';
                message       = "SDCli.exe output captured";
                SDPresent     = 'true';
                VolumeName    = $volNames;
                StorageSystem = $storSystem;
                MountPoints   = $MPs;
            }
        }
    } else {
        #Scenario where SDCLi is not present on the machine:
        New-Object -TypeName PSCustomObject -Property @{
                computer=$env:COMPUTERNAME;
                status='success';
                message='SDCli.exe is not present on the target machine.';
                SDPresent='false';
            }
    }
}