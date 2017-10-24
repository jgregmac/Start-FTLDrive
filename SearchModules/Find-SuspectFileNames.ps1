
[scriptblock]$block = {
    if ((get-service -Name W3SVC -ea SilentlyContinue) -or (get-process -name 'apache')) {
        #Get all local drives:
        [array]$localDrives = try {
                #Get local drives, filter out "A" drive and drives with no storage in use.
                # Note: Get-Volume probably would work better, but is not available in older 
                # versions of PowerShell.
                get-psdrive -ea Stop | Where-Object {$_.Provider.Name -match 'FileSystem'} |
                    Where-Object {$_.used -gt 0} 
                    Where-Object {$_.Name -notmatch 'A'}
            } catch {
                Write-Host "    Error: $Err.Exception" -fore Red
                New-Object -TypeName PSCustomObject -Property @{
                    computer=$env:COMPUTERNAME;
                    status='failure';
                    message=$_.Exception.Message
                }
            } 
    
        #Loop though all drives:
        foreach ($drive in $localDrives) {
            $regex = '^51f3d658bdc1eb8eimagesaspx\.aspx$|^Ac2\.asp;\.jpg$|^Admin_Ta\.asp$|^AspCms_Config\.asp$|' `
                + '^bftvp15111\.asp;\.jpg$|^cache\.asp$|^imagesaspx\.aspx$|^index_\.asp$|^jycpcx\.asp;\.jpg$|' `
                + '^lrrpv51331\.asp;\.jpg$|^md5\.asp$|^md5\.aspx$|^red\.asp$|^s\.asp$|^sdfg\.asp$|^Somnus\.asp$|' `
                + '^Sql\.asp$|^SqlIn\.asp$|^test\.asp$|^Thumb\.asp$|^uploadfile\.asp$|^v5she\.asp$|^v5she\.aSpX$|' `
                + '^weki\.asp$|^xianf\.ASP$|^zzz\.asp;\.jpg$|^XXerror2\.asp$|^__com\.asp$|^__upload\.asp$|' `
                + '^debugStream\.bin$|^ADODB\.Stream$|^test\.txt$|^avShell\.aspx$|^contact\.asp$|^error2\.asp$|' `
                + '^jquery_server\.aspx$|^Xerror2\.asp$'
            #Inspect all files on the drive. Capture files matching the pattern to '$Results'.  
            #  Use -Filter with Get-ChildItem (gci) whenever possible for best performance.
            #  Capture errors in 'gci' to $gciErrors, capture errors in select-string to $selStringErrors.
            #The Filter "*.asp*." is intended to match asp and aspx file extensions.  The trailing dot
            #  is intended to prevent matching files with asp or aspx in the middle of the name, such as
            #  'Microsoft.AspProvider.dll'
            #Traditionally, I have initialized arrays using '@()', but in this case my PowerShell 2.0 
            #  targets are returning a false count of results, so initialize using [array]$results instead:
            [array]$results = gci -Path $drive.root -Recurse -filter *.asp*. `
                -ErrorVariable gciErrors -ea SilentlyContinue |
                where-object {$_.name -match $regex}
        
            #Loop though results:
            if ($results.count -gt 0) {           #Skip loop if there are no results...
                foreach ($result in $results) {
                    #Return results to the calling process as a PSCustomObject:
                    Write-Host "    $env:computername : Found: $result" -fore Yellow
                    #Note: PowerShell 3.0 supports casting of PSCustomObjects using [pscustomobject],
                    #  But that will not work on our PowerShell 2.0 machines, so use the less compact
                    #  "New-Object" syntax.
                    New-Object -TypeName PSCustomObject -Property @{
                        computer=$env:COMPUTERNAME;
                        status='success';
                        message=$result.FullName
                    }
                } # End ForEach $results
            } # End If $results
        
            ### Error handling section:
            if ($gciErrors.count -gt 0) {
                foreach ($Err in $gciErrors) {
                    Write-Host "    Error: $Err.Exception" -fore Red
                    New-Object -TypeName PSCustomObject -Property @{
                        computer=$env:COMPUTERNAME;
                        status='failure';
                        message=$Err.Exception.Message
                    }
                }
            } # End If $gciErrors
        } # End ForEach $drives
    } else {
        write-host "    IIS is not running on computer $env:computername. Skipping." -ForegroundColor Gray
    }
} # End ScriptBlock