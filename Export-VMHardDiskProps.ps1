function Export-VMHardDiskProps {
<#
.SYNOPSIS
  PowerCLI Script to export all VMs virtual Hard Disk Properties into a csv File
.DESCRIPTION
  PowerCLI Script to export all VMs virtual Hard Disk Properties into a csv File
  This Script supports VMFS and VVOL Datastores
.NOTES
  Release 1.0
  Robert Ebneth
  February, 3rd, 2017
.LINK
  http://github.com/rebneth
.PARAMETER Cluster
  Lists vmdks from all VMs of this vSphere Cluster.
  DEFAULT: Lists vmdks from all VMs ALL vSphere Cluster.
.PARAMETER Filename
  Path and Filename for outputfile (csv)
.EXAMPLE
  Export-VMHardDiskProps -FILENAME d:\vmdk_props.csv
#>

  [CmdletBinding()]
  param(
  	[Parameter(Mandatory = $False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$true, Position = 0,
	HelpMessage = "Enter Name of vCenter Cluster")]
	[Alias("c")]
	[string]$CLUSTER,
   [Parameter(Mandatory = $False, Position = 1)]
   [string]$FILENAME = "d:\vmdk_props_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
  )

Begin { 
	# If we do not get Cluster from Input, we take them all from vCenter
	If ( !$Cluster ) {
		$Cluster_from_Input = (Get-Cluster | Select Name).Name | Sort}
	  else {
		$Cluster_from_Input = $CLUSTER
	}
	$OUTPUTFILENAME = CheckFilePathAndCreate "$FILENAME"
    $report = @()
} ### End Begin

Process {

    ########
    # Main #
    ########

	foreach ( $Cluster in $Cluster_from_input ) {
 	$status = Get-Cluster $Cluster
    If ( $? -eq $false ) {
		Write-Host "Error: Required Cluster $($Cluster) does not exist." -ForegroundColor Red
		break
    }
    Write-Host "Collecting vmdk info from all VMs of vSphere Cluster $($Cluster)..."
	$DatastoreTypeInfos = Get-Cluster $Cluster | Get-Datastore |select Name, Type
    $AllHardDisks = Get-Cluster $Cluster | Get-VM | Get-HardDisk
    $AllVMs = (Get-Cluster -Name $Cluster | Get-VM |select Name).Name | Sort
    Foreach ( $vm in $AllVMs ) {
    #Write-Host "VM: $vm"
    $AllHardDisks | Where { $_.Parent -Like "$vm" } | ForEach-Object {
        $HarddiskInfo = "" | Select-Object -Property Cluster,Parent,Name,DatastoreName,Type,Filename,CapacityGB,DiskType,Persistence,StorageFormat
        $HarddiskInfo.Cluster = $Cluster
        $HarddiskInfo.Parent = $_.Parent
        $HarddiskInfo.Name = $_.Name
        $Datastore = ($_.Filename).Split(']')[0]
        $Datastore = ($Datastore).Split('[')[1]
        $vmdkFileName = ($_.Filename).Split(']')[1]
        $vmdkFileName = ($vmdkFileName).Split(' ')[1]
        $DatastoreTypeInfo = $DatastoreTypeInfos | Where {$_.Name -eq $Datastore}
        $HarddiskInfo.Type = $DatastoreTypeInfo.Type
        $HarddiskInfo.DatastoreName = $Datastore
        $HarddiskInfo.Filename = $vmdkFileName
        $HarddiskInfo.CapacityGB = [math]::round(($_.CapacityGB), 2)
        $HarddiskInfo.DiskType = $_.DiskType
        $HarddiskInfo.Persistence = $_.Persistence
        $HarddiskInfo.StorageFormat = $_.StorageFormat
        $report += $HarddiskInfo
    } ### End Foreach HardDisk
    } ### End Foreach $vm
    } ### End Foreach $Cluster
} ### End Process

End {
    $report | Sort Cluster,Parent,Name | Format-Table -AutoSize
    Write-Host "Writing Outputfile $($OUTPUTFILENAME)..."
    $report | Sort Cluster,Parent,Name | Export-Csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
} ### End End

} ### End Function