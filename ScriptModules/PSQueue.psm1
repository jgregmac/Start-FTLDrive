function Get-JobOutput { 
    [cmdletBinding()]
    param (
        [array]$jobs
    )
    # What it does:
    #  Detects jobs with status other than "Running" (i.e. Completed|Stopped|Error).
    #  Receives output from the jobs and returns it to the calling process.
    
    $doneJobs = @(); #Completed jobs array
    $doneJobs += $jobs | Where-Object {$_.State -ne "Running"} ;
    if ($doneJobs.count -gt 0) { 
        Write-Host "  Number of jobs completed,stopped, or failed during this colletion cycle:" $doneJobs.count -ForegroundColor White
        
        #Return the job output to the caller:
        $doneJobs | ForEach-Object {
            try {
                $computer = $_.Location
                Receive-Job $_ -ea Stop
            } catch [System.Management.Automation.RemoteException] {
                #write-warning "$computer - $_.exception"
                [pscustomobject]@{
                    computer=$computer;
                    status='failure';
                    message=('PowerShell remoting error.')
                }
            } catch [System.Management.Automation.RuntimeException] {
                #Write-Warning "Error executing scriptBlock on $computer."
                [pscustomobject]@{
                    computer=$computer;
                    status='failure';
                    message=('Remote script block execution error. ')
                }
            } catch [System.UnauthorizedAccessException] {
                #write-warning "$computer Access Denied:" $_.Exception.toString()
                [pscustomobject]@{
                    computer=$computer;
                    status='failure';
                    message=('Unauthorized access exception. ')
                }
            } catch {
                #$out = "$computer - encountered unexpected error of type $_.exception.gettype().fullname with text $_.exception"
                #write-warning $out
                [pscustomobject]@{
                    computer=$computer;
                    status='failure';
                    message=('Other unknown error. Type: ' + $_.Exception.GetType().toString() + ' Message: ' + $_.Exception.Message)
                }
            }
        }

        #Cleanup the outstanding jobs:
        $doneJobs | Remove-Job -Force 
        Remove-Variable doneJobs
	
    } else {
        Write-Host "  No jobs completed during this collection cycle" -ForegroundColor Gray
	}
}

function Test-WSManAndPing {
    [cmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string]$computer
    )

    if (Test-WSMan $computer -ea SilentlyContinue) {
        $message = 'WSMan test was successful.'
        $status = 'success'
    } else {
        if (Test-Connection $computer -count 1 -ea SilentlyContinue) {
            $message = 'WSMan is not available, But ping is responding.'
        } else {
            $message = 'WSMan is not available, and ping is not responding.'
        }
        $status = 'failure'
    }

    [pscustomobject]@{
        computer=$computer;
        status = $status;
        message= $message
    }
}

function Invoke-Queue {
    [cmdletBinding()]
    param (
        [string[]]$queue,
        [switch]$remote = $true,
        [scriptblock]$scriptBlock,
        [int]$maxWorkers = 10,
        [int]$cycleTime = 5,
        [int]$timeout = 7200
    )
    [int]$queueCount = $queue.count
    
    $jobs = @()
    [int]$queueIndex = 0

    # Start master loop
    :master while ($queueCount -gt $queueIndex) { 
        :spawnWorker while ($jobs.count -lt $maxWorkers) {
            Write-Host "  Current running job count:" $jobs.count -ForegroundColor Gray
            Write-Host "  Current worker count is less than the desired maximum." -ForegroundColor Gray
            # Test to see if we have run out of items in the queue before spawning more workers:
            if ($queueCount -eq $queueIndex) {
                Write-Host "  Work queue exhausted.  Breaking out of worker spawning loop..." -ForegroundColor Cyan
                break spawnWorker
            }
            Write-Host "  Starting processing on:" $computer -ForegroundColor Cyan
            
            #Get the name of the current computer in the queue:
            [string]$computer = $queue[$queueIndex]

            #Find out if the computer is available in the network before starting a job for it.
            # If WSMan is not responding, return a failure status message instead of starting a job.
            Write-Host '    Testing WSMan and Ping on:' $computer -ForegroundColor White
            $testResults = Test-WSManAndPing ($computer)
            if ($testResults.status -eq 'failure') {
                Write-Host '    WSMan test failed.  Not starting a job for this computer.' -ForegroundColor Gray
                $testResults
                #Don't forget to increment to the next computer in the queue!
                $queueIndex++
                break spawnWorker
            }

            if ($remote) {
                $jobs += Invoke-Command -ComputerName $computer -AsJob -JobName $computer -ScriptBlock $Scriptblock
            } else {
                $jobs += Invoke-Command -AsJob -JobName $computer -ScriptBlock $Scriptblock -ArgumentList $computer
            }
            $queueIndex++
            Write-Host "    New job started.  Queue index incremented to $queueIndex of $queuecount" -ForegroundColor White
        }

        Write-Host "Collecting Jobs..." -ForegroundColor Green
        Get-JobOutput $jobs

        #Rebuild the jobs array with only running tasks (Completed, Stopped, or Failed):
        $jobs = @($jobs | Where-Object {$_.State -eq "Running"}) ;
        
        Start-Sleep -Seconds $cycleTime
    }
    #Wait up to two hours for remaining jobs to complete:
    Write-Host "Jobs have been started for all items in the queue.  Will wait for maximum seconds: " $timeOut -ForegroundColor Green
    $jobs | Wait-Job -Timeout $timeout | Stop-Job 
    Get-JobOutput $jobs
}

Export-ModuleMember -Function Invoke-Queue, Test-WSManAndPing