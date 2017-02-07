function Export-VMHardDiskProps {
<#
.SYNOPSIS
  PowerCLI Script to export all VMs virtual Hard Disk Properties into a csv File
.DESCRIPTION
  PowerCLI Script to export all VMs virtual Hard Disk Properties into a csv File
  This Script supports VMFS and VVOL Datastores
.NOTES
  Release 1.1
  Robert Ebneth
  February, 4th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Cluster
  Lists vmdks from all VMs of this vSphere Cluster.
  DEFAULT: Lists vmdks from all VMs ALL vSphere Cluster.
.PARAMETER Filename
  Path and Filename for outputfile (csv)
  DEFAULT: $($env:USERPROFILE)\vmdk_props_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
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
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\vmdk_props_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)

Begin { 
    # We need the common function CheckFilePathAndCreate
    Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
    if ( $? -eq $false) {
        Write-Error "Function CheckFilePathAndCreate is missing."
        break
    }
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
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUshQaolGSnuQXW+gBRNh9KBRg
# 3xWgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUZRDDoNMzMbqB
# efrnuZVFr2dfhFYwDQYJKoZIhvcNAQEBBQAEggEAVN8QJ/SVbsqjnE/yzSYp7dF1
# k2hVNq78EyBZOstd8aSdeMUl3LjIeduCU9pvqynO+Fw/rHblBbvGeATTRUsLmbEo
# A45pnU6HllZk+nPojs/K8CubnVBKWH5B0WDxQnieLlZZsMDofOH1VHL8oa/2UOQZ
# 0xiG3aVdULkY1c4/mG3Q4lX4ZCzQbAklUz8ab/d6istTdzRx3OYepegG0tfV/02a
# T28HVJxRsiZOqk8q/snPEE+EPx0m/Ph28owusWTa7rBbg2EqIxDTBnxYIRtdTp0z
# CwYe9u2aJamHkIBOJGNoLTe3hhKwbrRDKtpW5sy0Ju2d27wqPQaL+7wfmd+QeQ==
# SIG # End signature block
