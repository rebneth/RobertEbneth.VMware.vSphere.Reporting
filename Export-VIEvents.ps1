function Export-VIEvents {
<#
.SYNOPSIS
  Creates a csv file with the Events from vSphere Environment
.DESCRIPTION
  The function will export the Events from vSphere Environment
  and add them to a CSV file.
.NOTES
  Release 1.1
  Robert Ebneth
  February, 14th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Minutes
  Timeframe in minutes in which the VI Events are collected from vCenter
  DEFAULT: 1440 Minutes = 1 day
.PARAMETER Cluster
  Selects only ESXi servers from this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.PARAMETER Filename
  The path of the CSV file to use when exporting
  Default: "$($env:USERPROFILE)\VI-Events_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
.EXAMPLE
  Export-VIEvents -c <vSphere_Cluster> -t <Number of Minutes to the last even hour>
.EXAMPLE
  Get-Cluster | Export-VIEvents [-t <Number of Minutes to the last even hour>] -f d:\VIevents.csv
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 0,
	HelpMessage = "Enter Name of vCenter Cluster")]
	[Alias("c")]
	[string]$CLUSTER,
	[Parameter(Mandatory = $False, Position = 1,
    HelpMessage = "Enter time frame in number of minutes to collect")]
	[Alias("t")]
    [int]$minutes = 1440,
	[Parameter(Mandatory = $False, Position = 2)]
	[alias("f")]
	[string]$FILENAME = "$($env:USERPROFILE)\VI-Events_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)

Begin {
	# Check and if not loaded add powershell snapin
	if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
		Add-PSSnapin VMware.VimAutomation.Core}
	# We need the common function CheckFilePathAndCreate
    Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
    if ( $? -eq $false) {
        Write-Error "Function CheckFilePathAndCreate is missing."
        break
    }
    $AllEvents = @()
    #$StartTime = "24/10/2016"
    #$EndTime = "25/10/2016"
    $EndTime = Get-Date -Minute 0 -Second 0
	$StartTime = $EndTime.AddMinutes(-$($minutes))

	$OUTPUTFILENAME = CheckFilePathAndCreate $FILENAME

	Write-Host ""
	Write-Host "Collect VI Events within the last $minutes minutes from ESXi servers and export them to file ..."
	Write-Host ""

	} ### End Begin

Process {
  
	########
	# Main #
	########
	
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
        Write-Host "Collecting VI Events for ESXi Host $($clusterhost)..."
	    $HostEvents = @()
	    $headline = "" | Select ObjectName, CreatedTime, EventTypeId, FullFormattedMessage
	    $headline.ObjectName = "### $clusterhost.Name ###"
	    $AllEvents += $headline
	    $HostEvents = Get-VIEvent -Entity $clusterhost.Name -Start $StartTime -Finish $EndTime | select ObjectName, CreatedTime, EventTypeId, FullFormattedMessage
	    foreach ( $event in $HostEvents ) {
	     if ( -not $event.ObjectName -eq $clusterhost.Name ) {$event.ObjectName = $clusterhost.Name}
	     $AllEvents += $event
	    }
	}

} ### End Process
	
End {
	Write-Host "Writing File $($FILENAME)..."
    $AllEvents | Select ObjectName, CreatedTime, EventTypeId, FullFormattedMessage | Export-Csv -Delimiter ";" "$OUTPUTFILENAME" -noTypeInformation
	} ## End End

 } ### End Function

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUdF93bmNXC7Cf9jfSHxsbjrH8
# y8OgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUZnURYDOJtIXw
# cWDpY+V++QsucT0wDQYJKoZIhvcNAQEBBQAEggEAT2gBUnr/FL6HXRACCmNmtcPz
# waPtJnBEZaor8E1IdTMFYI+m6hHRyAX9Ylrdlwu1u7ntgy25a9WAc97xrzEMwT3h
# pMYLaf2M7/Q2j4dGkXs378Rvp+WEBTOaqLa6L1YToJRCpNrHQ0EaIs8k/F80a7i6
# CFBhpZp8yF+qCon/8wC9dbSxwSLrZtWLgYjqCcppHCsk1pIEk/lowqv3I2Mu8coC
# 2ws/tNehxXcVV8W5jx5ZZja/9dwS3gSjREwttL2gVNJVEITLLvxSDQrQvPe3aJ0p
# m/DX/clrHRK+BaZPUk/XH1pO47DLkGbPzlEUd2zHVU76Q83XCkn0h8zp/xMS9A==
# SIG # End signature block
