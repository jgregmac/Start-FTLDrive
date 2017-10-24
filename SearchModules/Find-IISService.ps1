$block = [scriptblock]{
    $svc = get-service w3svc -ea SilentlyContinue -ev gsError  
    if ($gsError) {
        new-object -typename pscustomobject -Property @{
            computer=$env:computername;
            status='success';
            message='notPresent'
        }
    } else {
        new-object -typename pscustomobject -Property @{
            computer=$env:computername;
            status='success';
            message=$svc.Status
        }
    }
}