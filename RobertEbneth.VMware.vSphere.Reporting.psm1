##############################################################################
##
## RobertEbneth.VMware.vSphere.Reporting.psm1
## Functions that are used for VMware vSphere Automation
## Release 1.0.0.3
## Date: 2017/07/12
##
## by Robert Ebneth
##
## ChangeLog:
## 1.0.0.3 Initial Release
##
##############################################################################


function CheckFilePathAndCreate {
<#
.Synopsis
   CheckFilePathAndCreate
.DESCRIPTION
   Checks Syntax of an Filepath, if Directory is Valid and creates this file if it does not exists
   If Filepath is empty or just a directory, a default Filename in a default Directory is used.
   This common function is used from vSphere Reporting Scripts
.NOTES
  Release 1.0
  Robert Ebneth
  February, 14th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER FILENAME
  Path and Filename for outputfile (csv) that has to be checked
.EXAMPLE
  CheckFilePathAndCreate TFILENAME
#>

param(
    [Parameter(Mandatory = $True, ValueFromPipeline=$false, Position = 0,
    HelpMessage = "Enter the path to the output file")]
    [string]$FILENAME
)

# Default Filename is empty
$OUTPUTFILENAME = ""

switch -wildcard ($FILENAME) 
    { 
        ".\*" {
                $FILENAME = $FILENAME.remove(0,2)
                $WORK_DIR = Get-Location
                $OUTPUTFILENAME = "$($WORK_DIR)\$($FILENAME)"} 
        "..\*" {
                $FILENAME = $FILENAME.remove(0,3)
                $WORK_DIR = Split-Path -parent (Get-Location)
                $OUTPUTFILENAME = "$($WORK_DIR)\$($FILENAME)"}  
        default {
                $DriveLetter = Split-Path $FILENAME -Qualifier -ErrorAction SilentlyContinue 
                if ($?) { 
                    # $FILENAME contains Drive Letter
                    if ($FILENAME -eq $DriveLetter) {
                        write-Error "Filename contains only drive letter"; break}
                    $FILENAMEPART = Split-Path $FILENAME -Leaf
                    if ($FILENAMEPART -eq "$($DriveLetter)\") {
                        write-Error "Filename contains only drive letter and \"; break}
                    $OUTPUTFILENAME = $FILENAME
                    }
                  else {
                    # $FILENAME contains NO Drive Letter
                    $FILENAMEPART = Split-Path $FILENAME -Leaf
                    if ( "$FILENAMEPART" -eq "$FILENAME" ) {
                        $WORK_DIR = Get-Location
                        $OUTPUTFILENAME = "$($WORK_DIR)\$($FILENAME)"}
                      else {
                        # drirecory\filename in the current still not supported
                        $WORK_DIR = Get-Location
                        $OUTPUTFILENAME = "$($WORK_DIR)\$($FILENAME)"
                        #Split-Path -Parent $
                        break}    
                    }
                } ### End default
           
    } ### End Switch statement

if ( $OUTPUTFILENAME -ne "" ) {
    # Now we check, if the Directory within the $FILENAME does exist
    $DirectoryPath = Split-Path $OUTPUTFILENAME -ErrorAction SilentlyContinue
    if ((Test-Path $DirectoryPath) -eq $False) { Write-Error "Directory does not exist: $DirectoryPath"; break}
    # Now we check, if the $FILENAME does exist
    if ((Test-Path $OUTPUTFILENAME) -eq $True)
    	{Remove-Item $OUTPUTFILENAME}
    New-Item $OUTPUTFILENAME -type file | out-null
    if (!$?) {
        Write-Error "Output File $OUTPUTFILENAME could not be created"; break
    }
    $OUTPUTFILENAME}
  else {
    break}

} ### End Function

function Export-VMPowerState {
<#
.SYNOPSIS
  Creates a csv file with the PowerState of each VM that contains comands to shutdown running VMs and restart them again.
.DESCRIPTION
  The function will export VM PowerState from vCenter Server
  and add them to a CSV file.
.NOTES
  Release 1.0
  Robert Ebneth
  February, 4th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Filename
  The path of the CSV file to use when exporting
.EXAMPLE
  Export-VMPowerState -DC “DC01” `
      -Filename “C:\VMLocations.csv”
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName=$false, Position = 0,
	HelpMessage = "Enter Name of vCenter Datacenter")]
	[string]$DC,
	[Parameter(Mandatory = $False)]
	[alias("f")]
	[string]$FILENAME = "$($PSScriptRoot)\VM_PowerState_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)

Begin {
    # We need the common function CheckFilePathAndCreate
    Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
    if ( $? -eq $false) {
        Write-Error "Function CheckFilePathAndCreate is missing."
        break
    }
	$OUTPUTFILENAME = CheckFilePathAndCreate $FILENAME
    $report = @()
} ### End Begin

Process {
        $ALL_VM_PowerStateInfo = @()
        $TimeStamp = Get-Date -UFormat "%A,%x %TUhr"
        $AllClusters = Get-Datacenter $DC | Get-Cluster | Sort-Object Name
        foreach ( $Cluster in $AllClusters ) {
            $VM_States = Get-Cluster $Cluster | Get-VM | Sort-Object Name | select Name, Powerstate
            foreach ($VM in $VM_States) {
                $VM_State = "" | select ClusterName,VMName,PowerState,TimeStamp,PowerOnCmd,PowerOffCmd
		        $VM_State.ClusterName = $Cluster.Name
		        $VM_State.VMName = $VM.Name
		        $VM_State.PowerState = $VM.PowerState
                $VM_State.TimeStamp = $TimeStamp
                If ( $VM_State.PowerState -Like "PoweredOn") {
                    $VM_State.PowerOnCmd = 'Start-VM -VM ' + $VM.Name + " -RunAsync"
                    $VM_State.PowerOffCmd = 'Stop-VMGuest -VM ' +$VM.Name + " -RunAsync"}
                  else {
                    $VM_State.PowerOnCmd = 'Stop-VMGuest -VM ' + $VM.Name + ' –RunAsync'
                    $VM_State.PowerOffCmd = 'Start-VM -VM ' + $VM.Name + ' –RunAsync'}
                $ALL_VM_PowerStateInfo += $VM_State
            }
        } ### Foreach Cluster
} ### End Process

End {
    Write-Host "Writing Output File $($OUTPUTFILENAME)..."
    $ALL_VM_PowerStateInfo | Select ClusterName,VMName,PowerState,TimeStamp,PowerOnCmd,PowerOffCmd | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
} ### End End

} ### End Function


# Load Powershell functions
. $PSScriptRoot\Export-DatastoreProps.ps1
. $PSScriptRoot\Export-DSMultipathingStatus
. $PSScriptRoot\Export-ESXiProperties.ps1
. $PSScriptRoot\Export-ESXiSWReleases.ps1
. $PSScriptRoot\Export-iSCSISettings
. $PSScriptRoot\Export-VMDiskIOStat.ps1
. $PSScriptRoot\Export-VMHardDiskProps.ps1
. $PSScriptRoot\Export-VMProperties.ps1
. $PSScriptRoot\Export-PortGroupNicTeaming.ps1
. $PSScriptRoot\Export-VMNetworkPNICProps.ps1
. $PSScriptRoot\Export-VIEvents.ps1
. $PSScriptRoot\Get-ESXiScratchLocation.ps1
. $PSScriptRoot\Get-vCenterLicensing.ps1
. $PSScriptRoot\Get-VMFilesystemFreespace.ps1

# This is optional but Best Practice
Export-ModuleMember -function CheckFilePathAndCreate
Export-ModuleMember -function Export-VMPowerState
# Export for loaded functions
Export-ModuleMember -function Export-DatastoreProps
Export-ModuleMember -function Export-DSMultipathingStatus
Export-ModuleMember -function Export-ESXiProperties
Export-ModuleMember -function Export-ESXiSWReleases
Export-ModuleMember -function Export-iSCSISettings
Export-ModuleMember -function Export-VMDiskIOStat
Export-ModuleMember -function Export-VMHardDiskProps
Export-ModuleMember -function Export-VMProperties
Export-ModuleMember -function Export-PortGroupNicTeaming
Export-ModuleMember -function Export-VMNetworkPNICProps
Export-ModuleMember -function Export-VIEvents
Export-ModuleMember -function Get-ESXiScratchLocation
Export-ModuleMember -function Get-vCenterLicensing
Export-ModuleMember -function Get-VMFilesystemFreespace