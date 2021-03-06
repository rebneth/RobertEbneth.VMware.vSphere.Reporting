﻿function Get-VMFilesystemFreespace {
<#
.SYNOPSIS
  Creates a Report and csv file with the List of VMs that have Filesystem with less than x percent free space
.DESCRIPTION
  The function will create a List of VMs that have Filesystem with less than x percent free space
.NOTES
  Release 1.1
  Robert Ebneth
  July, 12th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Cluster
  Selects only VMs from this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.PARAMETER PctMinFreeSpace
  This specifies the minimum required free filesystemspace per filesystem
.PARAMETER Filename
  The path of the CSV file to use when exporting
  Default: "$($env:USERPROFILE)\VMs_with_FS_that_have_less_than_x_percent_free_space_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
.EXAMPLE
  Get-VMFilesystemFreespace -c <vSphere_Cluster> -l <percentage of less than mimimum free space>
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $False, ValueFromPipeline=$true, Position = 0)]
	[Alias("c")]
	[string]$CLUSTER,
	[Parameter(Mandatory = $False, Position = 1,
    HelpMessage = "Enter percentage of less free space on VMs filesystems")]
	[Alias("l")]
    [int]$PctMinFreeSpace = 15,
	[Parameter(Mandatory = $False, Position = 2)]
	[alias("f")]
	[string]$FILENAME = "$($env:USERPROFILE)\VMs_with_FS_that_have_less_than_$($PctMinFreeSpace)_percent_free_space_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)

Begin {
	# Check and if not loaded add powershell core module
	if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        	Import-Module VMware.VimAutomation.Core
	}
	# We need the common function CheckFilePathAndCreate
	Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
	if ( $? -eq $false) {
        	Write-Error "Function CheckFilePathAndCreate is missing."
        	break
	}

	# Start of Settings 
	$Starttime = Date
	$Report = New-Object System.Collections.ArrayList
	$OUTPUTFILENAME = CheckFilePathAndCreate $FILENAME
	# End of Settings

	Write-Host ""
	Write-Host "Collect all VMs that have Filesystem with less than $PctMinFreeSpace percent free space ..."
	Write-Host ""

} ### End Begin

Process {
  
	########
	# Main #
	########
	
    # If we do not get Cluster from Input, we take them all from vCenter
	If ( !$Cluster ) {
		$Cluster_to_process = (Get-Cluster | Select Name).Name | Sort}
	  else {
		$Cluster_to_process = $CLUSTER
	}
    
	foreach ( $Cluster in $Cluster_to_process ) {
	$status = Get-Cluster $Cluster
    If ( $? -eq $false ) {
		Write-Host "Error: Required Cluster $($Cluster) does not exist." -ForegroundColor Red
		break
    }
    
    Foreach ($vm in (Get-Cluster -Name $Cluster | Get-VM | Where {-not $_.ExtensionData.Config.Template } | Where { $_.ExtensionData.Runtime.PowerState -eq "poweredOn" -And ($_.ExtensionData.Guest.toolsStatus -ne "toolsNotInstalled" -And $_.ExtensionData.Guest.ToolsStatus -ne "toolsNotRunning")})) {
	Foreach ($disk in $vm.ExtensionData.Guest.Disk){
		$PctFreeSpace = ([math]::Round(((100* ($disk.FreeSpace))/ ($disk.Capacity)),0))
		if ( $PctFreeSpace -le $PctMinFreeSpace) {
            $Details = New-object PSObject
	        $Details | Add-Member -Name Name -Value $vm.name -Membertype NoteProperty
    		$Details | Add-Member -Name "Diskpath" -MemberType NoteProperty -Value $Disk.DiskPath
			$Details | Add-Member -Name "DiskCapacity(MB)" -MemberType NoteProperty -Value ([math]::Round($disk.Capacity/ 1MB))
			$Details | Add-Member -Name "DiskFreeSpace(MB)" -MemberType NoteProperty -Value ([math]::Round($disk.FreeSpace / 1MB))
            $Details | Add-Member -Name "DiskFreeSpace(%)" -MemberType NoteProperty -Value $PctFreeSpace
            [void] $Report.Add($Details) 
		}
	}
}

    } ### End Foreach Cluster

} ### End Process
	
End {
	Write-Host "Writing File $($FILENAME)..."
    $Endtime = Date
    $Runtime = $Endtime - $Starttime
    Write-Host "Runtime: $($Runtime.TotalSeconds)"
    $Report | Sort-Object "DiskFreeSpace(%)" | Export-Csv -Delimiter ";" "$OUTPUTFILENAME" -noTypeInformation
    $Report | Sort-Object "DiskFreeSpace(%)" | FT -AutoSize
	} ## End End

 } ### End Function

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYs0WBoHXbFT1eqTeoyWUkoJb
# lg2gggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUqc01c1kaDcwQ
# AC5f7Hv47chyltIwDQYJKoZIhvcNAQEBBQAEggEAQ6xnRaoTZhmWZ6z7DBd7bRmg
# SFp+hXcbP8M4JMnpnYg/5jjC7BFj9rtkpdKG2gd+l45yr1sT7ahldmbXcsOoGPvm
# sSC2s/+zg2kMsqulY0JbGPcjX3i8VvCBKzWABdxy2ORW5y6/oq+0psbP6nwz0gGr
# iuRVrlVbMpzW2Kl73jiPqu6d3R1h4vZAeT+BkaLKXtjGxoL4eXMX2AagHjtuC79D
# XeoVviwzV/MSBTIGRkzlenPHluybUI0rw0NnheRW3G/5DesK7dJ9TOwntHSun+5C
# 9tBOBHTegsBWLKACseiyokWoejeUDpNm+AaCgmcSZcvP7skYqQ2X/B77wWHP/w==
# SIG # End signature block
