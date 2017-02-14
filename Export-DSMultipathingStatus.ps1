function Export-DSMultipathingStatus {
<#
.SYNOPSIS
  Creates a csv file with the Multipathing Information from SAN Datastores on VMware ESXi Hosts
.DESCRIPTION
  The function will export the Multipathing Information from SAN Datastores on VMware ESXi Hosts
  from vCenter Server and add them to a CSV file.
.NOTES
  Release 1.1
  Robert Ebneth
  February, 14th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Cluster
  Selects only ESXi servers from this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.PARAMETER Filename
  The path of the CSV file to use when exporting
  Default: $($env:USERPROFILE)\DSMultipathingStatus_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-DSMultipathingStatus [ -FILENAME d:\mp_status.csv ]
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $False)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False, Position = 0)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\DSMultipathingStatus_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
	# If we do not get Cluster from Input, we take them all from vCenter
	If ( !$Cluster ) {
		$Cluster_from_Input = (Get-Cluster | Select Name).Name | Sort}
	  else {
		$Cluster_from_Input = $CLUSTER
	}
	$OUTPUTFILENAME = CheckFilePathAndCreate "$FILENAME"
    $datastore = get-datastore | ?{$_.Name -notlike "*local"}
    $reportLunPathState = @()
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

        $AllHosts = get-cluster $cluster | get-vmhost | Where { $_.PowerState -eq "PoweredOn"} | Sort-Object Name
        $ALLClusterHostScsiLuns = get-cluster $cluster | get-vmhost | Get-ScsiLun -LunType disk | ?{$_.IsLocal -eq $false } | Sort-Object CanonicalName
        ForEach ($VMHost in $AllHosts) {
            Write-Host "Collecting Storage Multipathing information for ESXi host $($VMHost.Name)..."
            $VMHostScsiLuns = $ALLClusterHostScsiLuns | Where { $_.VMHost -Like "$VMHost" }
            $AllScsiPathsperHost = (Get-VMhost $VMHost | Get-esxcli).storage.core.path.list() | select AdapterTransportDetails, Device, RuntimeName, TargetTransportDetails, state | Sort-Object Device, RuntimeName
            $AllNMPDevices = (Get-VMhost $VMHost | Get-esxcli).storage.nmp.device.list() | select Device, PathSelectionPolicy, StorageArrayType, StorageArrayTypeDeviceConfig | Sort-Object Device, PathSelectionPolicy, StorageArrayType
            $DevPathInfo =@()
            ForEach ($VMHostScsiLun in $VMHostScsiLuns) {
		        $DevPathInfo = "" | select ClusterName, HostName, Datastorename, Vendor, Model, SerialNumber, ScsiCanonicalName, HBA_WWPN, RuntimeName, SizeGB, PathCount, ActivePathCount, BrokenPathCount, DisabledPathCount, Storage_Target_Port_Adress, PathState, Multipathing, PathSelectionPolicy, StorageArrayType, CommandsToSwitchPath, BlocksToSwitchPath, QueueDepth
		        $VMHostScsiLunPaths = $VMHostScsiLun | Get-ScsiLunPath
		        $AllPathInfo =@()
		        $ActivePathCount = 0
		        $BrokenPathCount = 0
		        $DisabledPathCount = 0
		        $NMPInfoPerDevice = $AllNMPDevices | ?{$_.Device -eq $VMHostScsiLun.CanonicalName}
                # We Buid up all the path infos for each lun
		        $PathInfoperLun = $AllScsiPathsperHost | ?{$_.Device -eq $VMHostScsiLun.CanonicalName}
		        foreach ($LunPath in $PathInfoperLun) {
        			$PathInfo = "" | select ClusterName, HostName, Datastorename, Vendor, Model, SerialNumber, ScsiCanonicalName, HBA_WWPN, RuntimeName, SizeGB, PathCount, ActivePathCount, BrokenPathCount, DisabledPathCount, Storage_Target_Port_Adress, PathState, Multipathing, PathSelectionPolicy, StorageArrayType, CommandsToSwitchPath, BlocksToSwitchPath, QueueDepth
		    	    $PathInfo.ClusterName = $cluster
			        $PathInfo.HostName = $VMHost.Name
			        $PathInfo.Datastorename = $datastore | Where-Object {($_.extensiondata.info.vmfs.extent | %{$_.diskname}) -contains $VMHostScsiLun.CanonicalName}|select -expand name
			        $PathInfo.ScsiCanonicalName = $VMHostScsiLun.CanonicalName
			        $PathInfo.RuntimeName = $LunPath.RuntimeName
			        $string = $LunPath.AdapterTransportDetails
			        if ( "$string" -like "WWNN*" ) {
				        $PathInfo.HBA_WWPN = ($string.Substring(($string.Length-23),23))}
        			  ELSE {
		        	  	$PathInfo.HBA_WWPN = $string }
			        $string = $LunPath.TargetTransportDetails
			        if ( "$string" -like "WWNN*") {
				        $PathInfo.Storage_Target_Port_Adress = $string.Substring(($string.Length-23),23)}
			          ELSE {
			  	        $PathInfo.Storage_Target_Port_Adress = $string}	
			        $PathInfo.PathState = $LunPath.State
			        switch ($LunPath.state) 
    			        { 
        		        active {$ActivePathCount++; $PathInfo.ActivePathCount = "1"}
				        dead {$BrokenPathCount++; $PathInfo.BrokenPathCount = "1"}
				        disabled {$DisabledPathCount++; $PathInfo.DisabledPathCount = "1"}
                        default {"N/A"}
				        }
			        $AllPathInfo += $PathInfo
		        }
                # $DevPathInfo is the headline for each detected storage device
		        $DevPathInfo.ClusterName = $cluster
		        $DevPathInfo.HostName = $VMHost.Name
		        $DevPathInfo.Datastorename = $datastore | Where-Object {($_.extensiondata.info.vmfs.extent | %{$_.diskname}) -contains $VMHostScsiLun.CanonicalName}|select -expand name
                $DevPathInfo.Vendor = $VMHostScsiLun.Vendor
                $DevPathInfo.Model = $VMHostScsiLun.Model
                $DevPathInfo.SerialNumber = $VMHostScsiLun.SerialNumber
		        $DevPathInfo.ScsiCanonicalName = $VMHostScsiLun.CanonicalName
		        $DevPathInfo.Multipathing=$VMHostScsiLun.multipathpolicy
                # the following properties depend on the multipathing settings
                if ( $VMHostScsiLun.multipathpolicy -Like "roundrobin" ) {
                    $DevPathInfo.CommandsToSwitchPath = $VMHostScsiLun.CommandsToSwitchPath
                    $DevPathInfo.BlocksToSwitchPath = $VMHostScsiLun.BlocksToSwitchPath
                    }
                  else {
                    $DevPathInfo.CommandsToSwitchPath = "CONTROLLED BY MP DRIVER"
                    $DevPathInfo.BlocksToSwitchPath = "CONTROLLED BY MP DRIVER"
                }
		        $DevPathInfo.QueueDepth=$VMHostScsiLun.ExtensionData.QueueDepth
                $DevPathInfo.SizeGB = [math]::round($($VMHostScsiLun.CapacityGB), 2)
		        $DevPathInfo.PathCount = $VMHostScsiLunPaths.Count
		        $DevPathInfo.ActivePathCount = $ActivePathCount
		        $DevPathInfo.BrokenPathCount = $BrokenPathCount
		        $DevPathInfo.DisabledPathCount = $DisabledPathCount
		        $DevPathInfo.Storage_Target_Port_Adress = ""
		        $DevPathInfo.PathState = ""
		        $DevPathInfo.PathSelectionPolicy = $NMPInfoPerDevice.PathSelectionPolicy
		        $DevPathInfo.StorageArrayType = $NMPInfoPerDevice.StorageArrayType
		        $reportLunPathState += $DevPathInfo
		        $reportLunPathState += $AllPathInfo
            } ### End Foreach SCSI Lun
        } ### End Foreach ESXi Host
    } ### End Foreach Cluster
} ### End Process

End {
    Write-Host "Writing Outputfile $($OUTPUTFILENAME)..."
    $reportLunPathState | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
} ### End End

} ### End function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUd5jP+QiLO2oXYDwdObyGfTHy
# Ss+gggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU5OuVmDFKF2FB
# zpCBoVRUAxBrglMwDQYJKoZIhvcNAQEBBQAEggEAmDyAcYFVpdJDd++pEA+UYlPb
# HW1MG4RH1llV91lPYO1afabWbfEmDYIFZxqI7ruiaJ9H9zihsFawP1D1JeKcJw7F
# o5quz+a5rhPlNJrw/rUXsKQQjcpgojEkD5+E2nFkkLe03lxwJviV4RGSuH/qtwhr
# +JxdWa5PsfgJnbrLMWOVsfUvCA6qjWUg0y3dvVmHT+16ko1mptJaY5EOkRVoXS39
# LmR6t/lV4fM+bD/LQCN0Vvxb42OGYgfceVZl/BESKxY9pHckiRgWMAugnVPRFsJW
# gAPs49sOJVK2j9DimvCqeAHzZJT9yproIhMLUP1wxQZLNr3vJfpIFPWSZcuWcg==
# SIG # End signature block
