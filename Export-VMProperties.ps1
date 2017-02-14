function Export-VMProperties {
<#
.SYNOPSIS
  Creates a csv file with the Properties from VMware Virtual Machines
.DESCRIPTION
  The function will export the Properties from VMware Virtual Machines from vCenter Server and add them to a CSV file.
.NOTES
  Release 1.0
  Robert Ebneth
  February, 14th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Filename
  Path and Filename for outputfile (csv)
  DEFAULT: $($env:USERPROFILE)\VM_inventory_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-VMProperties [ -FILENAME d:\vms.csv ]
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $False, Position = 0)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\VM_inventory_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
    $OUTPUTFILENAME = CheckFilePathAndCreate $FILENAME
    # temporary memory table for output
    $allvminfo = @()
} ### End Begin

Process {

    ########
    # Main #
    ########

    Write-Host ""
    Write-Host "Datacollection for Virtual Machine properties information..."
    Write-Host ""

    # for speed-up we need some temporary tables
    # that provide indexes for Name/Id relations of VMHosts, Datastores
    $vms = Get-view -ViewType VirtualMachine | Sort-Object Name
    $DsIDs = Get-Datastore | select Name, Id | Sort-Object Name
    $HostIDs = Get-VMHost | select Name, Id, Parent | Sort-Object Name
    $AllVMCapacity = Get-VM |select Name,UsedSpaceGB,ProvisionedSpaceGB
    foreach ( $TP in Get-Template ) {
	    $TPHDs = $TP | Get-HardDisk
	    $TPCapacityGB = 0
	    foreach ( $HD in $TPHDs ) {
		    $TPCapacityGB = $TPCapacityGB + $HD.CapacityGB      
	    }
	    $TMP = ""| select Name, UsedSpaceGB, ProvisionedSpaceGB
	    $TMP.Name = $TP.Name
	    $TMP.UsedSpaceGB = $TPCapacityGB
	    $TMP.ProvisionedSpaceGB = $TPCapacityGB
	    $AllVMCapacity += $TMP
    }

    foreach($vm in $vms){
	Write-Host "Get properties for VM $($vm.Name)..."
	$vminfo = "" | Select Name, OSFullName, PowerState, Version, ToolsVersion, ClusterName, Host, CPUCount, NumvSocket, NumCoresperSocket, OverallCpuUsageMHz, cpuHotAddEnabled, cpuHotRemoveEnabled, RAMAssignedGB, MemoryReservedMB, GuestMemoryUsageMB, MemoryHotAddEnabled, ProvisionedSpaceGB, UsedSpaceGB, UnusedSpaceGB, Datastore, IsTemplate
    if ($?) {		
	    $UsedSpace = ""
	    $ProvisionedSpace = ""
		$VMCapInfo = $AllVMCapacity | ?{$_.Name -eq $vm.Name }
		$ProvisionedSpaceGB = [math]::round($($VMCapInfo.ProvisionedSpaceGB[0]), 2)
		$UsedSpaceGB = [math]::round(($VMCapInfo.UsedSpaceGB), 2)
		$UnUsedSpaceGB = $ProvisionedSpaceGB - $UsedSpaceGB		
	    $vminfo.Name = $vm.Name
	    $vminfo.OSFullName = $vm.config.guestFullName
	    $vminfo.Version = $vm.Config.Version
	    $vminfo.ToolsVersion = $vm.Config.tools.toolsVersion	
	    $vminfo.CPUCount = $vm.Config.hardware.NumCpu
        $vminfo.NumvSocket = ($vm.config.hardware.NumCPU/$vm.config.hardware.NumCoresPerSocket)
        $vminfo.NumCoresperSocket = $vm.config.hardware.NumCoresPerSocket
        $vminfo.cpuHotAddEnabled = $vm.config.cpuHotAddEnabled
        $vminfo.cpuHotRemoveEnabled = $vm.config.cpuHotRemoveEnabled
        $vminfo.OverallCpuUsageMHz = $vm.Summary.QuickStats.OverallCpuUsage
        $vminfo.RAMAssignedGB = [math]::round(($vm.config.hardware.MemoryMB/1024), 0)
		$vminfo.MemoryReservedMB = $vm.ResourceConfig.MemoryAllocation.Reservation
        $vminfo.GuestMemoryUsageMB = $vm.Summary.QuickStats.GuestMemoryUsage
        $vminfo.MemoryHotAddEnabled = $vm.Config.memoryHotAddEnabled
	    $vminfo.ProvisionedSpaceGB = $ProvisionedSpaceGB
	    $vminfo.UsedSpaceGB = $UsedSpaceGB
	    $vminfo.UnUsedSpaceGB = $UnUsedSpaceGB
	    $vminfo.PowerState = $vm.Runtime.PowerState
		$IdString = $vm.Runtime.Host.Type+"-"+$vm.Runtime.Host.Value
		$VMHostInfo = $HostIDs | ?{$_.Id -eq "$IdString" }
		$vminfo.Host = $VMHostInfo.Name
        $vminfo.ClusterName = $VMHostInfo.Parent
		$IdString = $vm.Datastore.Type+"-"+$vm.Datastore.Value
		$dsinfo = $DsIDs | ?{$_.Id -eq "$IdString" }
		$vminfo.Datastore = $dsinfo.Name
		$vminfo.IsTemplate = $vm.Config.Template
	    $allvminfo += $vminfo
    }
    } ### End foreach $vm

    Write-Host "Virtual Machine inventory from vCenter $VCSERVER FINISHED..."
    Write-Host ""
} ### End Process

End {
    Write-Host "Writing Outputfile $($OUTPUTFILENAME)..."
    $allvminfo | Select Name, OSFullName, PowerState, Version, ToolsVersion, ClusterName, Host, CPUCount, NumvSocket, NumCoresperSocket, OverallCpuUsageMHz, cpuHotAddEnabled, cpuHotRemoveEnabled, RAMAssignedGB, MemoryReservedMB, GuestMemoryUsageMB, MemoryHotAddEnabled, ProvisionedSpaceGB, UsedSpaceGB, UnusedSpaceGB, Datastore, IsTemplate | Sort-Object ClusterName, Name | Export-Csv -Delimiter ";" "$OUTPUTFILENAME" -noTypeInformation
} ### End End

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbRWm2qCnFMFu9zHy2cvkupKK
# M5egggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUzL2aX6VO9ydT
# 7tgqcN1N1yrXx6swDQYJKoZIhvcNAQEBBQAEggEAP3NOpG4EydDJXZZUjJCV4kxK
# WmNlp79knhYiJKG2Eu7dXEteVxThu0fAVeJC4AZD+SDUMBn4bgSic9Ue5SiiAhLh
# EpT72EwEiRUjPo50dJKTsKn+rplsPdBzuo+UbTMwmHauWjjMOtV7OPN/TlJNUJUg
# v74LNbzfHmQJfU2xI4jc4nL38a4i+CHwfm+4UeCihvDUyH6WVDqzeJhxEWyfAsE8
# OcR9IZhPMID3DPs9jb8HKELwbnrH0FcsS0mMZeuhckqxRFJSV8WyYTSryE+69Pjr
# enkQzcuwuUaUVVklXNIZcfC1opLP8ccn2ve9+8JtLIrjXcldlsDx2aSeH1sHPg==
# SIG # End signature block
