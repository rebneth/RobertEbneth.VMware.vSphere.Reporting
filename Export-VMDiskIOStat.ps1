Function Export-VMDiskIOStat {
<#
.SYNOPSIS
  Creates a csv file with the Disk IO Performance from VMware vSphere VMs
.DESCRIPTION
  Creates a csv file with the Disk IO Performance from VMware vSphere VMs
.NOTES
  Release 1.1
  Robert Ebneth
  February, 14th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Cluster
  Selects only VMs from this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.PARAMETER minutes
  timeframe within the disk io stats will be collected
  DEFAULT: 360 Minutes = 6 hours
.PARAMETER Filename
  The path of the CSV file to use when exporting
  Default: $($env:USERPROFILE)\VM_IOPs_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-VMDiskIOStat -Cluster <vSphere_Cluster> -t 360
.EXAMPLE
  Get-Cluster | Export-VMDiskIOStat -t 360
#>

param(
    [Parameter(Mandatory = $True, ValueFromPipeline=$true, Position = 0)]
    [string]$Cluster,
	[Parameter(Mandatory = $False)]
	[Alias("t")]
    [int]$minutes = 360,
	[Parameter(Mandatory = $False)]
    [Alias("f")]
	[string]$FILENAME = "$($env:USERPROFILE)\VM_IOPs_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
} ### End End
	
} ### End function

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDlIdcUMeYS8mYzngt+iKXLrT
# gOigggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
# AQUFADApMScwJQYDVQQDDB5Sb2JlcnRFYm5ldGhJVFN5c3RlbUNvbnN1bHRpbmcw
# HhcNMTcwMjA0MTI0NjQ5WhcNMjIwMjA1MTI0NjQ5WjApMScwJQYDVQQDDB5Sb2Jl
# cnRFYm5ldGhJVFN5c3RlbUNvbnN1bHRpbmcwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCdqdh2MLNnST7h2crQ7CeJG9zXfPv14TF5v/ZaO8yLmYkJVsz1
# tBFU5E1aWhTM/fk0bQo0Qa4xt7OtcJOXf83RgoFvo4Or2ab+pKSy3dy8GQ5sFpOt
# NsvLECxycUV/X/qpmOF4P5f4kHlWisr9R6xs1Svf9ToktE82VXQ/jgEoiAvmUuio
# bLLpx7/i6ii4dkMdT+y7eE7fhVsfvS1FqDLStB7xyNMRDlGiITN8kh9kE63bMQ1P
# yaCBpDegi/wIFdsgoSMki3iEBkiyF+5TklatPh25XY7x3hCiQbgs64ElDrjv4k/e
# WJKyiow3jmtzWdD+xQJKT/eqND5jHF9VMqLNAgMBAAGjRjBEMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAdBgNVHQ4EFgQUXJLKHJBzYZdTDg9Z
# QMC1/OLMbxUwDQYJKoZIhvcNAQEFBQADggEBAGcRyu0x3vL01a2+GYU1n2KGuef/
# 5jhbgXaYCDm0HNnwVcA6f1vEgFqkh4P03/7kYag9GZRL21l25Lo/plPqgnPjcYwj
# 5YFzcZaCi+NILzCLUIWUtJR1Z2jxlOlYcXyiGCjzgEnfu3fdJLDNI6RffnInnBpZ
# WdEI8F6HnkXHDBfmNIU+Tn1znURXBf3qzmUFsg1mr5IDrF75E27v4SZC7HMEbAmh
# 107gq05QGvADv38WcltjK1usKRxIyleipWjAgAoFd0OtrI6FIto5OwwqJxHR/wV7
# rgJ3xDQYC7g6DP6F0xYxqPdMAr4FYZ0ADc2WsIEKMIq//Qg0rN1WxBCJC/QxggHe
# MIIB2gIBATA9MCkxJzAlBgNVBAMMHlJvYmVydEVibmV0aElUU3lzdGVtQ29uc3Vs
# dGluZwIQPWSBWJqOxopPvpSTqq3wczAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU/3Iw3eTChX1f
# 9F8CYCcR14r5P0owDQYJKoZIhvcNAQEBBQAEggEAT9tcq0BNhFNUgTynIsIsrbEd
# O9vCzfAbftbNcBvvqA8VBHFwfH5e4I5eZDson6PEIISfgzX4Dwdzpb6JAhW+4R85
# 7ROyVNidg6gCBpObJH8w/K1Hdw5fAWnR+lPiaNdr9Yp2OLvKiXOODUrd2qUT4mdA
# dZWdkQMzzFHdeVIcv0S0v5rDjn89pcIHChZ9axJuLCP6sQFabk4aU2FLn01WmeYf
# Q0JE1OWYNsHshD1jJ3Qpz/R2F3F0lQoN+3Ivv7p4Xl/hCCuEgIotmHP1LeronKWa
# 7gqhukRgP+qg32X3WAvKoHI/XmNgGCMcY+Y6hRE0U8FyfGs7S8gSiBjzDxah6Q==
# SIG # End signature block
