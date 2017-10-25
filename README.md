# Start-FTLDrive
A PowerShell script module for multi-threaded remoting to multiple computers in an organization.
Developed primarially to allow speedy vulnerability scanning and device reporting, but the modular
nature of the cmdlet allows for virtually unlimited applications.

"FTLDrive" modules are all PowerShell based.  Anyone with pretty basic PowerShell scripting skills
should be able to author an FTLDrive module.  No C#, Python, Ruby, or YAML knowledge is required.

This project is in no way associated with Ansible, and is in no way as feature-rich or powerful.
But Ansible did serve as an inspiration for this work, so props to those guys!

## Content Highlights:
### Start-FTLDrive
This cmdlet will start an asynchronous search all servers in the test, dev, or prod forests for "interesting things". 
Things of interest are defined in separate scriptblock "module" files, to be stored in the 
"ServerSearchModules" subdirectory.  Output is a CSV file in the format: computer,status,message

The script currently takes four arguments:

- ModulePath:  
  Path to the search module to be used for this run of the script
- ThrottleLimit  
  Default = 50 searches  
  Maximum number of simultaneous computer searches to run (invoked as PowerShell Jobs).
- CycleTime:  
  Default = 10 seconds  
  Time to wait between tests for completed jobs. 
- Computer:
  A computer or list of computers upon which to run the desired search module.  Script can take 
  either 'computer' or 'namedScope' parameters.
- NamedScope:  
  Context for the search.  
  This is a Yale-specific scope, and can be targeted at all managed computers
  in one of the PROD, TEST, or DEV Active Directory forests. 

This is intended to be an evolving utility.  In the future, I intend to add more refinements and features:

1. Common functions that will be added to the module's script block, possibly used to simplify output. 
2. Verbose logging options
3. More flexible logging options, including custom log names/suffixes and output options (CliXML, Excel, others?)

New search modules need to adhere to the following standards:

1. If the module will return any structured data beyond the standard computer,status, and message properties, you must specify these at the top of the module using the 'localHeaders' string array:

        [string[]]$localHeaders = @('[localProperty1]','[localProperty2]',...)
        
2. The module should be contained within a single file which contains a single scriptblock object named 'block':

        [scriptblock]$block = { insert code here }

3. The module should return only PSCustomObjects with the following format:

        New-Object -TypName PSCustomObject -Property @{
          computer=$env:COMPUTERNAME;
          status='[success|failure]';
          message='Custom message in String format here';
          [localProperty1]='[property1]';
          [localProperty2]='[property2]'
        }
  