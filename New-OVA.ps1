#requires -version 4

# Script to deploy StorSimple OVA (On-Premises Virtual Array) version 1.1.1.0  
# For more information see https://superwidgets.wordpress.com/
# Sam Boutros - 22 January, 2016 - v1.0

#region Input

$HyperVHost  = 'xHost11'
$VMName      = 'vStorSimple3'
$VMPath      = 'D:\VMs' # must be local path on $HyperVHost above
$VHDPath     = '\\xHost15\install\Golden\hcs_onpremva.fbl_ur1_hcs.10266.0.151214-2130.amd64fre.vhd'
# Download from http://download.microsoft.com/download/2/3/A/23ACD076-46FB-4FA0-BD46-B5FB6490AA3E/hcs_onpremva.fbl_ur1_hcs.10266.0.151214-2130.amd64fre%20VHD.zip


$VMRAM       = 8GB
$VMCores     = 4
$VMGen       = 1
$DriveDSize  = 500 # GB
$LogFile     = ".\New-OVA-$(Get-Date -format yyyy-MM-dd_HH-mm-sstt).txt"

#endregion


function Log {
<# 
 .Synopsis
  Function to log input string to file and display it to screen

 .Description
  Function to log input string to file and display it to screen. Log entries in the log file are time stamped. Function allows for displaying text to screen in different colors.

 .Parameter String
  The string to be displayed to the screen and saved to the log file

 .Parameter Color
  The color in which to display the input string on the screen
  Default is White
  Valid options are
    Black
    Blue
    Cyan
    DarkBlue
    DarkCyan
    DarkGray
    DarkGreen
    DarkMagenta
    DarkRed
    DarkYellow
    Gray
    Green
    Magenta
    Red
    White
    Yellow

 .Parameter LogFile
  Path to the file where the input string should be saved.
  Example: c:\log.txt
  If absent, the input string will be displayed to the screen only and not saved to log file

 .Example
  Log -String "Hello World" -Color Yellow -LogFile c:\log.txt
  This example displays the "Hello World" string to the console in yellow, and adds it as a new line to the file c:\log.txt
  If c:\log.txt does not exist it will be created.
  Log entries in the log file are time stamped. Sample output:
    2014.08.06 06:52:17 AM: Hello World

 .Example
  Log "$((Get-Location).Path)" Cyan
  This example displays current path in Cyan, and does not log the displayed text to log file.

 .Example 
  "$((Get-Process | select -First 1).name) process ID is $((Get-Process | select -First 1).id)" | log -color DarkYellow
  Sample output of this example:
    "MDM process ID is 4492" in dark yellow

 .Example
  log "Found",(Get-ChildItem -Path .\ -File).Count,"files in folder",(Get-Item .\).FullName Green,Yellow,Green,Cyan .\mylog.txt
  Sample output will look like:
    Found 520 files in folder D:\Sandbox - and will have the listed foreground colors

 .Link
  https://superwidgets.wordpress.com/category/powershell/

 .Notes
  Function by Sam Boutros
  v1.0 - 08/06/2014
  v1.1 - 12/01/2014 - added multi-color display in the same line

#>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')] 
    Param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeLine=$true,
                   ValueFromPipeLineByPropertyName=$true,
                   Position=0)]
            [String[]]$String, 
        [Parameter(Mandatory=$false,
                   Position=1)]
            [ValidateSet("Black","Blue","Cyan","DarkBlue","DarkCyan","DarkGray","DarkGreen","DarkMagenta","DarkRed","DarkYellow","Gray","Green","Magenta","Red","White","Yellow")]
            [String[]]$Color = "Green", 
        [Parameter(Mandatory=$false,
                   Position=2)]
            [String]$LogFile,
        [Parameter(Mandatory=$false,
                   Position=3)]
            [Switch]$NoNewLine
    )

    if ($String.Count -gt 1) {
        $i=0
        foreach ($item in $String) {
            if ($Color[$i]) { $col = $Color[$i] } else { $col = "White" }
            Write-Host "$item " -ForegroundColor $col -NoNewline
            $i++
        }
        if (-not ($NoNewLine)) { Write-Host " " }
    } else { 
        if ($NoNewLine) { Write-Host $String -ForegroundColor $Color[0] -NoNewline }
            else { Write-Host $String -ForegroundColor $Color[0] }
    }

    if ($LogFile.Length -gt 2) {
        "$(Get-Date -format "yyyy.MM.dd hh:mm:ss tt"): $($String -join " ")" | Out-File -Filepath $Logfile -Append 
    } else {
        Write-Verbose "Log: Missing -LogFile parameter. Will not save input string to log file.."
    }
}


#region Create VM

<#
# Need Hyper-V Powershell module - can import session commands using implicit remoting as follows:
$Session = New-PSSession -ComputerName $HyperVHost
Invoke-Command -ScriptBlock { Import-Module Hyper-V } -Session $Session 
Import-PSSession -Session $Session -Module Hyper-V | Out-Null 
#>

# Get vSwitch
log 'Checking vSwitches on Hyper-V Host',$HyperVHost Green,Cyan $LogFile
$vSwitches = Get-VMSwitch -ComputerName $HyperVHost
if ($vSwitches.count -gt 1) {
    $vSwitchName = $vSwitches[0].Name
} else {
    $vSwitchName = $vSwitches.Name
}
log 'Using vSwitch:',$vSwitchName Green,Cyan $LogFile

# Copy VHD to VM Path
if (Test-Path $VHDPath) {
    $VMUNCPath = "\\$HyperVHost\$($VMPath.Replace(':','$'))"
    log 'Copying VHD file from',$VHDPath,'to',"$VMUNCPath\$VMName..." Green,Cyan,Green,Cyan $LogFile -NoNewLine
    if (!(Test-Path "$VMUNCPath\$VMName")) { New-Item -Path $VMUNCPath -ItemType Directory -Name $VMName -Force | Out-Null }
    if (!(Test-Path "$VMUNCPath\$VMName")) { log 'Error: unable to create folder',"$VMUNCPath\$VMName" Magenta,Yellow $LogFile ; break }
    Copy-Item -Path $VHDPath -Destination "$VMUNCPath\$VMName" -Force -Confirm:$false 
    log 'Done' Green $LogFile
} else {
    log 'Error: unable to access VHD file at',$VHDPath Magenta,Yellow $LogFile ; break
}

# Create VM
log 'Creating VM',$VMName,'on',$HyperVHost,'Hyper-V host, with the following parameters:' Green,Cyan,Green,Cyan,Green $LogFile
log '       Boot Disk:      ',$VHDPath Green,Cyan $LogFile
log '       Memory (Static):',$($VMRAM/1MB),'MB' Green,Cyan,Green $LogFile
log '       Generation:     ',$VMGen Green,Cyan $LogFile
log '       Path:           ',$VMPath Green,Cyan $LogFile
$CDrive = "$VMPath\$VMName\$(Split-Path $VHDPath -Leaf)" 
New-VM -ComputerName $HyperVHost -VHDPath $CDrive -MemoryStartupBytes $VMRAM -Generation $VMGen -Name $VMName -Path $VMPath -SwitchName $vSwitchName | Out-Null
try { Get-VM -ComputerName $HyperVHost -Name $VMName } catch { throw 'Failed to create VM' }

log 'Configuring',$VMCores,'cores' Green,Cyan,Green $LogFile
log (Set-VMProcessor -ComputerName $HyperVHost -VMName $VMName -Count $VMCores -CompatibilityForMigrationEnabled $true -Passthru | Out-String) Green $LogFile

log 'Creating and adding a dynamically expanding thin provisioned',$DriveDSize,'GB disk on virtual SCSI controller' Green,Cyan,Green $LogFile
$DDrive = "$VMPath\$VMName\$VMName-DriveD.vhdx"
log (New-VHD -ComputerName $HyperVHost –Path $DDrive –BlockSizeBytes 128MB –LogicalSectorSize 4KB –SizeBytes ($DriveDSize*1GB) -Dynamic | Out-String) Green $LogFile
log (Add-VMHardDiskDrive -ComputerName $HyperVHost -VMName $VMName -ControllerType SCSI -Path $DDrive -Passthru | Out-String) Green $LogFile

log 'Starting VM',$VMName Green,Cyan $LogFile
log (Start-VM -ComputerName $HyperVHost -Name $VMName -Passthru | Out-String) Green $LogFile

#endregion


# Next log into the VM and set its IP address as detailed in
# https://azure.microsoft.com/en-us/documentation/articles/storsimple-ova-deploy2-provision-hyperv/#step-3-start-the-virtual-device-and-get-the-ip