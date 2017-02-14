function Export-iSCSISettings {
<#
.SYNOPSIS
  Creates a csv file with the iSCSISettings for VMware ESXi Hosts
.DESCRIPTION
  The function will export iSCSISettings from vCenter Server and add them to a CSV file.
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
  Default: $($env:USERPROFILE)\ESXi_iSCSI_Properties_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-iSCSISettings -Filename “C:\ESXi_iSCSI_Settings.csv”
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $False)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\ESXi_iSCSI_Properties_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv" 
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
    $report = @()

    Write-Host ""
    Write-Host "Get ESXi iSCSI settings and export them to file $OUTPUTFILENAME ..."
    Write-Host ""
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

	$All_Cluster_Hosts = Get-Cluster -Name $cluster | Get-VMHost | Sort-Object Name
	foreach ( $ESXi_Host in $All_Cluster_Hosts) {
		Write-Host "Getting iSCSI information for Host $($ESXi_Host.Name)..."
        $iscsi_hba = Get-VMHost $ESXi_Host | Get-VMHostHba -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}
		if ( $iscsi_hba.count -eq 1 ) {
            # We have some settings that are per vmhba not per vmk Kernel Port
            # Dynamic/static targets and Advanced Options
            $DynamicTargets = Get-IScsiHbaTarget -IScsiHba $iscsi_hba -Type Send | Sort Address | Get-Unique
            $DynamicTargetString = ""
            $tgtcount = 1
            foreach ($target in $DynamicTargets) {
                $DynamicTargetString = "$($DynamicTargetString)$($target.Address):$($target.Port)"
                if ( $tgtcount -lt $DynamicTargets.Length ) { $DynamicTargetString = $DynamicTargetString + ";"} $tgtcount++ }
            $StaticTargets = Get-IScsiHbaTarget -IScsiHba $iscsi_hba -Type Static | Sort Address | Get-Unique
            $StaticTargetString = ""
            $tgtcount = 1
            foreach ($target in $StaticTargets) {
                $StaticTargetString = "$($StaticTargetString)$($target.Address):$($target.Port)"
                if ( $tgtcount -lt $StaticTargets.Length ) { $StaticTargetString = $StaticTargetString + ";"} $tgtcount++ }
            $AdvancedOptions = $iscsi_hba.ExtensionData.AdvancedOptions
            $DelayedAck = $AdvancedOptions | ?{$_.Key -eq "DelayedAck" } | Select-Object -ExpandProperty Value
			$LoginTimeout = $AdvancedOptions | ?{$_.Key -eq "LoginTimeout" } | Select-Object -ExpandProperty Value
			$NoopTimeout = $AdvancedOptions | ?{$_.Key -eq "NoopTimeout" } | Select-Object -ExpandProperty Value
            # now we collect infos per vmk VM Kernel Port
    		$ESXCli = Get-EsxCli -VMHost $ESXi_Host.Name
			$iSCSI_INFO = $ESXCli.iscsi.networkportal.list($iscsi_hba)
			foreach ( $vmkport in $iSCSI_INFO ) {
				$iSCSI_HBA_INFO = "" | select vSphereClusterName, ESXiHostName, iscsi_hba, PortGroup, Vmknic, IPv4, IPv4SubnetMask, MACAddress, VlanId, MTU, NICDriver, NICDriverVersion, NICFirmwareVersion, CurrentSpeed, LinkUp, PathStatus, DelayedAck, LoginTimeout, NoopTimeOut, DynamicTargets, StaticTargets
				$iSCSI_HBA_INFO.vSphereClusterName = $cluster
				$iSCSI_HBA_INFO.ESXiHostName = $ESXi_Host.Name
				$iSCSI_HBA_INFO.iscsi_hba = $iscsi_hba
				$iSCSI_HBA_INFO.PortGroup = $vmkport.PortGroup
				$iSCSI_HBA_INFO.Vmknic = $vmkport.Vmknic
				$iSCSI_HBA_INFO.IPv4 = $vmkport.IPv4
				$iSCSI_HBA_INFO.IPv4SubnetMask = $vmkport.IPv4SubnetMask
				$iSCSI_HBA_INFO.MACAddress = $vmkport.MACAddress
				$iSCSI_HBA_INFO.VlanID = $vmkport.VlanID
				$iSCSI_HBA_INFO.MTU = $vmkport.MTU
				$iSCSI_HBA_INFO.NICDriver = $vmkport.NICDriver
				$iSCSI_HBA_INFO.NICDriverVersion = $vmkport.NICDriverVersion
				$iSCSI_HBA_INFO.NICFirmwareVersion = $vmkport.NICFirmwareVersion
				$iSCSI_HBA_INFO.CurrentSpeed = $vmkport.CurrentSpeed
				$iSCSI_HBA_INFO.LinkUp = $vmkport.LinkUp
				$iSCSI_HBA_INFO.PathStatus = $vmkport.PathStatus
			    $iSCSI_HBA_INFO.DelayedAck = $DelayedAck
			    $iSCSI_HBA_INFO.LoginTimeout = $LoginTimeout
			    $iSCSI_HBA_INFO.NoopTimeout = $NoopTimeout
                $iSCSI_HBA_INFO.DynamicTargets = $DynamicTargetString   
                $iSCSI_HBA_INFO.StaticTargets = $StaticTargetString						
				$report += $iSCSI_HBA_INFO
			}
		}
		  else	{
			$iSCSI_HBA_INFO = "" | select vSphereClusterName, ESXiHostName, iscsi_hba, PortGroup, Vmknic, IPv4, IPv4SubnetMask, MACAddress, VlanId, MTU, NICDriver, NICDriverVersion, NICFirmwareVersion, CurrentSpeed, LinkUp, PathStatus, DelayedAck, LoginTimeout, NoopTimeOut, CurrentDynamiciSCSITargets
			$iSCSI_HBA_INFO.vSphereClusterName = $cluster.Name
			$iSCSI_HBA_INFO.ESXiHostName = $ESXi_Host.Name
			$iSCSI_HBA_INFO.iscsi_hba = "N/A"
			$iSCSI_HBA_INFO.PortGroup = "N/A"
			$iSCSI_HBA_INFO.Vmknic = "N/A"
			$iSCSI_HBA_INFO.IPv4 = "N/A"
			$iSCSI_HBA_INFO.IPv4SubnetMask = "N/A"
			$iSCSI_HBA_INFO.MACAddress = "N/A"
			$iSCSI_HBA_INFO.VlanID = "N/A"
			$iSCSI_HBA_INFO.MTU = "N/A"
			$iSCSI_HBA_INFO.NICDriver = "N/A"
			$iSCSI_HBA_INFO.NICDriverVersion = "N/A"
			$iSCSI_HBA_INFO.NICFirmwareVersion = "N/A"
			$iSCSI_HBA_INFO.CurrentSpeed = "N/A"
			$iSCSI_HBA_INFO.LinkUp = "N/A"
			$iSCSI_HBA_INFO.PathStatus = "N/A"
			$iSCSI_HBA_INFO.DelayedAck = "N/A"
			$iSCSI_HBA_INFO.LoginTimeout = "N/A"
			$iSCSI_HBA_INFO.NoopTimeout = "N/A"
            $iSCSI_HBA_INFO.DynamicTargets = "N/A"
            $iSCSI_HBA_INFO.StaticTargets = "N/A"
			$iSCSI_HBA_INFO | Format-Table -AutoSize
			$report += $iSCSI_HBA_INFO
		  }
	}
}

} ### End Process

End {
	Write-Host "Writing File $($FILENAME)..."
    $report | Format-Table -AutoSize
    $report | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
} ## End End
  
} ### End function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHrrHeb0lr2WtyLLFlGmWeG0h
# 8SCgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUAjN3Lw8hX26G
# IsY+VEy8JF20kn8wDQYJKoZIhvcNAQEBBQAEggEAFXf5m7dUIlGVJ3laqwNZy0Q2
# abLOhve6S+NSqn9FWLElh8bXSRetKau0ipUUHAuQbg5u6QrS/pZ8QAaKGmAdyODK
# KbCu5ZowEN+kU5vbGbgB4H+TWIsyT9IFwutdvdfqZoGEg7fTUAyNieQDmKLulvYj
# ++GugsCBSUX/yUcdaWb9uFwYarLvuVHOnegt4zHP8IDqldQ0bX2Uv2jhfv8Ms8W5
# Lg31g87cRJ+Bjt6YOpNdYjrQZldeM2+Q5pIV96fMSzX700lv7XLXoyhysIeiIIr2
# Z7LgpPz9ohKogWb8VoB3iil7Pu9n9c34t+IqsbFgMXL/5Wf1HmzcLok5Bq7XXg==
# SIG # End signature block
