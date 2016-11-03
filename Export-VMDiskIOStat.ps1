Function Export-VMDiskIOStat {
<#
.SYNOPSIS
  Shows Disk IO Performance from VMware vSphere VMs
.DESCRIPTION
.NOTES
  Release 1.0
  Robert Ebneth
  November, 3rd, 2016
.LINK
  http://github.com/rebneth
.EXAMPLE
  Export-VMDiskIOStat -Cluster <vSphere_Cluster> -t 360
.EXAMPLE
  Get-Cluster | Export-VMDiskIOStat -t 360
#>


	param(
    [Parameter(Mandatory = $True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 0,
    HelpMessage = "Enter Name of vCenter Cluster")]
    [string]$Cluster,
	[Parameter(Mandatory = $True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 1,
    HelpMessage = "Enter time frame in number of minutes to collect")]
	[Alias("t")]
    [int]$minutes,
	[Parameter(Mandatory = $False, ValueFromPipeline=$false,
	HelpMessage = "Enter the path to the csv output file")]
    [Alias("f")]
	[string]$FILENAME = "$($PSScriptRoot)\VM_IOPs_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
	)

Begin {
	# Get all available metrics by # Get-StatType |sort
    $metrics = "disk.numberwrite.summation","disk.numberread.summation"
    $finish = Get-Date -Minute 0 -Second 0
	$start = $finish.AddMinutes(-$($minutes))
	$report = @()
    Write-Host "###################################"
    Write-Host "# Exporting VM Disk IO Statistics #"
    Write-Host "###################################"
	}

Process { 
    $vms = Get-Cluster $Cluster | Get-VM | where {$_.PowerState -eq "PoweredOn"}
    $stats = Get-Stat -Realtime -Stat $metrics -Entity $vms -Start $start
    $interval = $stats[0].IntervalSecs
     
    $lunTab = @{}
    foreach($ds in (Get-Datastore -VM $vms | where {$_.Type -eq "VMFS"})){
      $ds.ExtensionData.Info.Vmfs.Extent | %{
        $lunTab[$_.DiskName] = $ds.Name
      }
    }

    $ClusterReport = @()
    $ClusterReport = $stats | Group-Object -Property {$_.Entity.Name},Instance | %{
      New-Object PSObject -Property @{
        VM = $_.Values[0]
        Disk = $_.Values[1]
        IOPSWriteAvg = [math]::round((($_.Group | `
          where{$_.MetricId -eq "disk.numberwrite.summation"} | `
          Measure-Object -Property Value -Average).Average / $interval) `          ,2)
        IOPSReadAvg = [math]::round((($_.Group | `
          where{$_.MetricId -eq "disk.numberread.summation"} | `
          Measure-Object -Property Value -Average).Average / $interval) `          ,2)
        IOPSReadMax = [math]::round((($_.Group | `
          where{$_.MetricId -eq "disk.numberread.summation"} | `
          Measure-Object -Property Value -Maximum).Maximum / $interval) `          ,2)
        IOPSWriteMax = [math]::round((($_.Group | `
          where{$_.MetricId -eq "disk.numberwrite.summation"} | `
          Measure-Object -Property Value -Maximum).Maximum / $interval) `          ,2)
        IOPSTotalAvg = [math]::round(((($_.Group | where{$_.MetricId -eq "disk.numberwrite.summation"} | Measure-Object -Property Value -Average).Average / $interval) + `
         (($_.Group | where{$_.MetricId -eq "disk.numberread.summation"} | Measure-Object -Property Value -Average).Average / $interval)),2 )
        Datastore = $lunTab[$_.Values[1]]
      }
    }
    $report += $ClusterReport
} ### End process

End {
	Write-Host "Writing File $($FILENAME)..."
	$report | Select VM, Datastore, Start, Finish, IOPSWriteMax, IOPSWriteAvg, IOPSReadMax, IOPSReadAvg, IOPSTotalAvg | Sort-Object -Descending IOPSTotalAvg |Export-Csv $FILENAME -Delimiter ";" -NoTypeInformation
	}
	
} ### End function
