$localHeaders = @('file','users')
$block = [scriptblock]{
    #Find-EncryptedFiles.ps1
    # Locates files on local drives that have been encrypted using EFS.  
    # Captures to the variable "$encFiles", and echos to console.

    #Create a file attribute object for comparing existing file attributes:
    $encrypted = [system.io.fileattributes]::Encrypted

    #Enumerate local drives, with free space greater than zero (suggesting that it is not removable),
    # and not the "A" drive, which is a troublemaker.
    $drives = get-psdrive | 
        Where-Object {$_.provider -match 'FileSystem'} | 
        Where-Object {$_.free -gt 0} | 
        Where-Object {$_.Name -notmatch 'A'} |
        Select-Object -ExpandProperty root

    #Create a pipeline for all local drives:
    $drives | ForEach-Object {
        Get-ChildItem $_ -recurse -erroraction silentlycontinue | 
            Where-Object {($_.attributes -band $encrypted) -eq $encrypted} | # Where-Object clause checks to see if the file is encrypted
                ForEach-Object {
                    # User cipher.exe to determine which users can decrypt the file.  Looks for "YALE\" as an indicator of username info being present.
                    # There probably is a better way to do this discovery, but I don't have time to search right now.
                    $uInfo = & cipher.exe /C $_.FullName | Where-Object {$_ -match 'YALE\\'} | % {$_.trim()}
                    new-object -typename pscustomobject -Property @{
                        computer=$env:computername;
                        status='success';
                        file=$_.FullName;
                        users=$uInfo
                    }
                } 
        #End Get-ChildItem pipeline
    } #End $Drives pipeline
}

