function Export-PortGroupNicTeaming {
<#
.SYNOPSIS
  Creates a csv file with VMware vNetwork Portgroup to vmnic relationship and vSW/vPG properties
.DESCRIPTION
  Creates a csv file with VMware vNetwork Portgroup to vmnic relationship and vSW/vPG properties
.NOTES
  Release 1.3
  Robert Ebneth
  April, 19th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Cluster
  Selects only ESXi servers from this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.PARAMETER Filename
  The path and filename of the CSV file to use when exporting
  DEFAULT: $($env:USERPROFILE)\vSwitch_portgroup_nicteaming_and_shaping_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-PortGroupNicTeaming -FILENAME d:\vm_vSW_vPG_NicTeaming.csv
#>

[CmdletBinding()]
 param(
    [Parameter(Mandatory = $False, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 0,
    HelpMessage = "Enter Name of vCenter Cluster")]
    [Alias("c")]
    [string]$CLUSTER,
    [Parameter(Mandatory = $false, Position = 1)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\vSwitch_portgroup_nicteaming_and_shaping_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)

Begin {
	# Check and if not loaded add powershell snapin
	if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
		Add-PSSnapin VMware.VimAutomation.Core}
	if (!(Get-Module VMware.VimAutomation.Vds -ErrorAction SilentlyContinue )) {
		Import-Module VMware.VimAutomation.Vds}
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

    foreach ( $VMHost in (Get-Cluster -Name $Cluster | Get-VMHost | Sort Name)) {
        Write-Host "Collecting Virtual Networking information for ESXi host $($VMHost.Name)..."
		$esxi_
        $vNicTab = @{}
		$VMHost.ExtensionData.Config.Network.Vnic | %{ $vNicTab.Add($_.Portgroup,$_)}
        foreach($vsw in (Get-VirtualSwitch -VMHost $VMHost)){
            $VSWprops = "" | Select Cluster, ESXiHost, vSwitch, Portgroup, VLAN, ActiveNIC, StandbyNIC, Device, Mac, DHCP, IP, SubnetMask, MTU, AllowPromiscuous, MacChanges, ForgedTransmits, TsoEnabled, Policy, NotifySwitches, RollingOrder, ShapingEnabled, AverageBandwidth, PeakBandwidth, BurstSize
			$VSWprops.Cluster = $Cluster
			$VSWprops.ESXiHost = $($VMHost.Name)
			$VSWprops.vSwitch = $vsw
			$VSWprops.PortGroup = "vSwitch Settings"
            if ($vsw.extensiondata.spec.policy.Nicteaming.NicOrder.ActiveNic) {
                $VSWprops.ActiveNIC = [string]::Join(',',$vsw.extensiondata.spec.policy.Nicteaming.NicOrder.ActiveNic)}
            if ($vsw.extensiondata.spec.policy.Nicteaming.NicOrder.StandbyNic) {
                $VSWprops.StandbyNIC = [string]::Join(',',$vsw.extensiondata.spec.policy.Nicteaming.NicOrder.StandbyNic)}
            $VSWprops.MTU = $vsw.Mtu
            $VSWprops.AllowPromiscuous = $vsw.extensiondata.Spec.Policy.Security.AllowPromiscuous
            $VSWprops.MacChanges = $vsw.extensiondata.Spec.Policy.Security.MacChanges
            $VSWprops.ForgedTransmits = $vsw.extensiondata.Spec.Policy.Security.ForgedTransmits
            $VSWprops.Policy = $vsw.extensiondata.Spec.Policy.Nicteaming.Policy
			$VSWprops.NotifySwitches = $vsw.extensiondata.Spec.Policy.Nicteaming.NotifySwitches
			$VSWprops.RollingOrder = $vsw.extensiondata.Spec.Policy.Nicteaming.RollingOrder
            $VSWprops.ShapingEnabled = $vsw.ExtensionData.Spec.Policy.ShapingPolicy.ShapingEnabled
            $VSWprops.AverageBandwidth = $vsw.ExtensionData.Spec.Policy.ShapingPolicy.AverageBandwidth
            $VSWprops.PeakBandwidth = $vsw.ExtensionData.Spec.Policy.ShapingPolicy.PeakBandwidth
            $VSWprops.BurstSize = $vsw.ExtensionData.Spec.Policy.ShapingPolicy.BurstSize
            $report += $VSWprops
			foreach($pg in (Get-VirtualPortGroup -VirtualSwitch $vsw)){
				$PGprops = "" | Select Cluster, ESXiHost, vSwitch, Portgroup, VLAN, Setting, ActiveNIC, StandbyNIC, Device, Mac, DHCP, IP, SubnetMask, MTU, AllowPromiscuous, MacChanges, ForgedTransmits, TsoEnabled, Policy, NotifySwitches, RollingOrder, ShapingEnabled, AverageBandwidth, PeakBandwidth, BurstSize
				$PGprops.Cluster = $Cluster
				$PGprops.ESXiHost = $($VMHost.Name)
				$PGprops.vSwitch = $vsw
				$PGprops.PortGroup = $pg.Name
				$PGprops.VLAN = $pg.VLanId
                if ($pg.extensiondata.spec.policy.Nicteaming.NicOrder.ActiveNic) {
                    $PGprops.ActiveNIC = [string]::Join(',',$pg.extensiondata.spec.policy.Nicteaming.NicOrder.ActiveNic)}
                if ($pg.extensiondata.spec.policy.Nicteaming.NicOrder.StandbyNic) {
                    $PGprops.StandbyNIC = [string]::Join(',',$pg.extensiondata.spec.policy.Nicteaming.NicOrder.StandbyNic)}	
				if ($vNicTab.ContainsKey($pg.Name)) {
                    $PGprops.Device = $vNicTab[$pg.Name].Device
                    $PGprops.Mac = $vNicTab[$pg.Name].Spec.Mac
                    $PGprops.Dhcp = $vNicTab[$pg.Name].Spec.Ip.Dhcp
                    $PGprops.IP = $vNicTab[$pg.Name].Spec.Ip.IpAddress
                    $PGprops.SubnetMask = $vNicTab[$pg.Name].Spec.Ip.SubnetMask
                    $PGprops.MTU = $vNicTab[$pg.Name].Spec.Mtu
                    $PGprops.AllowPromiscuous = $vNicTab[$pg.Name].Spec.Policy.Security.AllowPromiscuous
                    $PGprops.MacChanges = $vNicTab[$pg.Name].Spec.Policy.Security.MacChanges
                    $PGprops.ForgedTransmits =$vNicTab[$pg.Name].Spec.Policy.Security.ForgedTransmits
                    $PGprops.Policy = $vNicTab[$pg.Name].Spec.Policy.Nicteaming.Policy
                    $PGprops.TsoEnabled = $vNicTab[$pg.Name].Spec.TsoEnabled
                    $PGprops.ShapingEnabled = $vNicTab[$pg.Name].Spec.Spec.Policy.ShapingPolicy.Enabled
                    $PGprops.AverageBandwidth = $vNicTab[$pg.Name].Spec.Spec.Policy.ShapingPolicy.AverageBandwidth
                    $PGprops.PeakBandwidth = $vNicTab[$pg.Name].Spec.Spec.Policy.ShapingPolicy.PeakBandwidth
                    $PGprops.BurstSize = $vNicTab[$pg.Name].Spec.Spec.Policy.ShapingPolicy.BurstSize
                }
                $PGprops.Policy = $pg.extensiondata.Spec.Policy.Nicteaming.Policy
				$PGprops.NotifySwitches = $pg.extensiondata.Spec.Policy.Nicteaming.NotifySwitches
				$PGprops.RollingOrder = $pg.extensiondata.Spec.Policy.Nicteaming.RollingOrder
                $report += $PGprops				
			} ### End Foreach Portgroup
		} ### End Foreach vSwitch
    } ### End foreach esxi host
} ### End foreach cluster

} ### End Process

    End {
    $report | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
	Write-Host "Writing Outputfile $($OUTPUTFILENAME)..."
    $report | ft -AutoSize
} ### End End

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUzl+BUYK/bnjnfyC900nIHFUy
# WcGgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUrnBOFJjNChOh
# fEkwpCEje6gr+LkwDQYJKoZIhvcNAQEBBQAEggEAcwRhbMsw/SaHt+31iyw4FRIH
# 5iQ7vU19Dwfk/gsDB3knvGz0y8sXXfqSmsDwY02SIwq9iv7Rtxwy2/25LTds1R/R
# fpKMEg1/TgR4f8UE3cTw2JyYKLClZ8FyWwU6yDPpOCfLPA7Zd2U8HCCoOH0SGFCe
# 0CGyNgsOwOCzfDMEqY05S5VWi8MJ1Sqhsz2QIVTUcMgRS74kWZ+N8iicPQboK7EP
# NfgEywgpTLOpVfejXJdRsDAUUOcFitXZsM2f28/KkkZ9OmHzTbdrGgMOYDWZTCGQ
# +cVdzXLnvOIyhmUeYcf3PwXIYw/YsRXMDXcQXOJfAfg7fFWIu4xrAQ9NXVBMRw==
# SIG # End signature block
