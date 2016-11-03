function Export-VIEvents {
  <#
.SYNOPSIS
  Creates a csv file with the Events from vSphere Environment
.DESCRIPTION
  The function will export the Events from vSphere Environment
  and add them to a CSV file.
.NOTES
  Release 1.0
  Robert Ebneth
  November, 3rd, 2016
.LINK
  http://github.com/rebneth
.PARAMETER Filename
  The path of the CSV file to use when exporting
  Default: "$($PSScriptRoot)\VI-Events_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
.EXAMPLE
  Export-VIEvents -c <vSphere_Cluster> -t <Number of Minutes to the last even hour>
.EXAMPLE
  Get-Cluster | Export-VIEvents -t <Number of Minutes to the last even hour>
#>

	[CmdletBinding()]
	param(
	[Parameter(Mandatory = $True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 0,
	HelpMessage = "Enter Name of vCenter Cluster")]
	[Alias("c")]
	[string]$CLUSTER,
	[Parameter(Mandatory = $True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 1,
    HelpMessage = "Enter time frame in number of minutes to collect")]
	[Alias("t")]
    [int]$minutes,
	[Parameter(Mandatory = $False, ValueFromPipeline=$false, Position = 1,
	HelpMessage = "Enter the path to the csv output file")]
	[alias("f")]
	[string]$FILENAME = "$($PSScriptRoot)\VI-Events_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
	)

Begin {
    $AllEvents = @()
	#$OUTPUTFILENAME = CheckFilePathAndCreate VMware_ESXi_Host_Events_per_Cluster_$($vSPHERE_CLUSTER).csv $FILENAME
    #$StartTime = "24/10/2016"
    #$EndTime = "25/10/2016"
    $EndTime = Get-Date -Minute 0 -Second 0
	$StartTime = $EndTime.AddMinutes(-$($minutes))

	Write-Host ""
	Write-Host "Collect Events from ESXi servers and export them to file $($FILENAME) ..."
	Write-Host ""

	} ### End Begin

Process {
  
	########
	# Main #
	########

	### $OUTPUTFILENAME = CheckFilePathAndCreate ESXi_iSCSI_Properties.csv $FILENAME
	
	$status = Get-Cluster $Cluster
    If ( $? -eq $false ) {
		Write-Host "Error: Required Cluster $($Cluster) does not exist." -ForegroundColor Red
		break
    }

    $headline = "" | Select ObjectName, CreatedTime, EventTypeId, FullFormattedMessage
    $headline.ObjectName = "### Cluster: $($Cluster) ###"
    $AllEvents += $headline
    $ALL_CLUSTER_HOSTS = Get-Cluster -Name $Cluster | Get-VMHost | Sort-Object Name
    
    foreach ( $clusterhost in $ALL_CLUSTER_HOSTS) {
	    $HostEvents = @()
	    $headline = "" | Select ObjectName, CreatedTime, EventTypeId, FullFormattedMessage
	    $headline.ObjectName = "### $clusterhost.Name ###"
	    $AllEvents += $headline
	    # Get-VIEvent -Entity <SERVERNAME> -Start 08/12/2015 -Finish 31/12/2015 -MaxSamples 100 -Types Warning,Error
	    $HostEvents = Get-VIEvent -Entity $clusterhost.Name -Start $StartTime -Finish $EndTime | select ObjectName, CreatedTime, EventTypeId, FullFormattedMessage
	    foreach ( $event in $HostEvents ) {
	     if ( -not $event.ObjectName -eq $clusterhost.Name ) {$event.ObjectName = $clusterhost.Name}
	     $AllEvents += $event
	    }
	}

} ### End Process
	
End {
	Write-Host "Writing File $($FILENAME)..."
    $AllEvents | Select ObjectName, CreatedTime, EventTypeId, FullFormattedMessage | Export-Csv -Delimiter ";" "$FILENAME" -noTypeInformation
	} ## End End

 } ### End Function
