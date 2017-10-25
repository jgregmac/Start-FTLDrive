<#
  .SYNOPSIS
Get-PrivAccountUsage.ps1 - Determines where privileged accounts are being used

  .DESCRIPTION
This script will search for usage of privileged accounts provided in the "accounts" parameter on a 
list of systems provided in the "computers" parameter.  The script will search for use of these 
accounts in Scheduled Tasks, Services, and IIS App Pools.

  .NOTES
Intent is to convert this to a search module for Start-FTLDrive, but it is not working in that context yet.

  .TODO
Convert to Start-FTLDrive module.
Need to capture list of hosts where probing failed and write out to an error log (see all instances of write-error).
Need to find some common mechanisms for probling "Application Identity" on remote IIS instances.
Figure out how to remove YALE-isms from the code.

#>
[scriptblock]$block = {
    function Get-ScheduledTaskUser{
        #Retrieves all scheduled tasks and their 'runas' accounts from the server specified in '$env:computername'
        Write-Verbose  "Getting scheduled Tasks from: $env:computername"
        $tasks = @()
        
        #Note that while this XML parsing may look very smart, it will not work 
        #  on Server 2008 and earlier, because the /XML flag is not supported 
        #  on that version of SCHTASKS.exe.  Use "CSV" instead.
        [xml]$xmlTasks = schtasks.exe /query /s $env:computername /XML ONE
        if ($LASTEXITCODE -ne 0) {
            Throw $error[0].exception
        }
        [int]$count = $xmlTasks.tasks.task.count  
        [int]$i = 0
        for ($i=0;$i -lt $count;$i++) {
            $tName = $xmlTasks.tasks.'#comment'[$i].Substring(2)
            if ($xmlTasks.tasks.task[$i].principals.principal.userid) {$uid = $xmlTasks.tasks.task[$i].principals.principal.userid}
            if ($xmlTasks.tasks.task[$i].principals.principal.id) {$uid = $xmlTasks.tasks.task[$i].principals.principal.id}
            $taskInfo = [pscustomObject]@{name=$tname;runAsUser=$uid}
            $tasks += $taskInfo
        }
        return $tasks
    }
    function Get-PrivAccountUsage {
        param(
            [string[]]$accounts = @()
        )
        set-psdebug -Strict

        #Historical account search:
        $cmpName = $env:COMPUTERNAME

        #Build a WMI filter for accounts to detect:
        [string]$filter = ''
        $accounts | ForEach-Object {$filter += "(StartName = 'YALE\\$_') OR "}
        $filter = $filter.Substring(0,$filter.Length-3)

        #find services running as privileged accounts:
        $privSvcs = @()

        $services = @()
        #Hint: Discover your system error types:
        # $error[0].Exception.GetType().FullName
        try {
            $services = Get-WmiObject -Namespace 'root\cimv2' -Class 'win32_service' -Filter $filter -ea Stop
        } catch [System.UnauthorizedAccessException] {
            #Access denied error:
            Write-Warning $cmpName + ' - Access Denied'
            $out = $cmpName + ",getServices-accessDenied"
            $out 
        } catch [System.Runtime.InteropServices.COMException] {
            #RPC Error:
            Write-Warning "$cmpName - RPC Error "
            $Out = $cmpName + ",getServices-RPCError"
            $out
        } catch {
            #Everything else:
            Write-Warning $_.exception
            Write-Warning $_.exception.GetType().FullName
            $out = $cmpName + ",getServices-unknownError"
            $out 
        }
        if ($services) {
            foreach ($service in $services) {
                Write-Host "$cmpName - Found privileged account "$service.startName" for service "$service.name
                $svc = [pscustomobject]@{computer=$cmpName;name=$service.name;account=$service.startName}
                $privSvcs += $svc
            }
        }

        $privSvcs 

        #Find Scheduled Tasks running as privileged accounts:
        # Tried to use:
        # http://windowsitpro.com/powershell/how-use-powershell-report-scheduled-tasks
        # But COM was really unreliable.  Now attempting to use schtasks.exe with XML output.
        $privTasks = @()

        #Build a regex that will check for presense of all desired privileged accounts:
        [string]$regEx = ''
        $accounts | ForEach-Object {$regEx += $_ + '|'}
        $regEx = $regEx.Substring(0,$regEx.Length-1)

        $tasks = @()
        try {
            $tasks = Get-ScheduledTaskUser -ComputerName $cmpName
        } catch [System.Management.Automation.RemoteException] {
            write-warning "$cmpName - $_.exception"
            $out = "$cmpName,getTasks-NetworkPathNotFound"
            $Out | out-file $failedOutFile -Append
            continue cmpTasks
        } catch [System.UnauthorizedAccessException] {
            write-warning "$cmpName - $_.exception"
            $out = "$cmpName,getTasks-Connect-accessDenied"
            $Out | out-file $failedOutFile -$Append
            continue cmpTasks
        } catch {
            write-warning "$cmpName - encountered unexpected error of type $_.exception.gettype().fullname with text $_.exception"
            $out = "$cmpName,getTasks-Connect-" + $_.exception.gettype().fullname
            $Out | out-file $failedOutFile -$Append
            continue cmpTasks
        }
        
        if ($taskS) {
            forEach ($task in $tasKs) {
                if ($task.runAsUser -match $regEx) {
                    Write-Verbose $cmpName + ' - Found privileged account ' + $task.runasuser + ' for task ' + $task.name
                    $pTaskInfo = [pscustomobject]@{computer=$cmpName; taskname=$task.name; account=$task.runAsUser; os=$computer.OperatingSystem; svcPack=$computer.OperatingSystemServicePack}
                    $privTasks += $pTaskInfo
                }
            }
        }

        $privTasks 

        <#
        #Now look for IIS App Pools:
        $provPools = @()
        foreach ($computer in $computers) {
        }
        #>
    }
}