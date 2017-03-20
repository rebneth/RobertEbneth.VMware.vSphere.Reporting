function Export-PortGroupNicTeaming {
<#
.SYNOPSIS
  Creates a csv file with VMware vNetwork Portgroup to vmnic relationship and vSW/vPG properties
.DESCRIPTION
  Creates a csv file with VMware vNetwork Portgroup to vmnic relationship and vSW/vPG properties
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
  The path and filename of the CSV file to use when exporting
  DEFAULT: $($env:USERPROFILE)\vSwitch_to_vmnic_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
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
    [string]$FILENAME = "$($env:USERPROFILE)\vSwitch_portgroup_nicteaming_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
            $PGprops = "" | Select Cluster, ESXiHost, vSwitch, Portgroup, VLAN, Setting, ActiveNIC, StandbyNIC, Device, Mac, DHCP, IP, SubnetMask, MTU, TsoEnabled, Policy, NotifySwitches, RollingOrder, ShapingEnabled, AverageBandwidth, PeakBandwidth, BurstSize
			$PGprops.Cluster = $Cluster
			$PGprops.ESXiHost = $($VMHost.Name)
			$PGprops.vSwitch = $vsw
			$PGprops.PortGroup = "vSwitch Settings"
            $PGprops.Setting = "vSw"
            $PGprops.MTU = $vsw.Mtu
            $PGprops.Policy = $vsw.extensiondata.Spec.Policy.Nicteaming.Policy
			$PGprops.NotifySwitches = $vsw.extensiondata.Spec.Policy.Nicteaming.NotifySwitches
			$PGprops.RollingOrder = $vsw.extensiondata.Spec.Policy.Nicteaming.RollingOrder
            $PGprops.ShapingEnabled = $vsw.ExtensionData.Spec.Policy.ShapingPolicy.ShapingEnabled
            $PGprops.AverageBandwidth = $vsw.ExtensionData.Spec.Policy.ShapingPolicy.AverageBandwidth
            $PGprops.PeakBandwidth = $vsw.ExtensionData.Spec.Policy.ShapingPolicy.PeakBandwidth
            $PGprops.BurstSize = $vsw.ExtensionData.Spec.Policy.ShapingPolicy.BurstSize
            $report += $PGprops
			foreach($pg in (Get-VirtualPortGroup -VirtualSwitch $vsw)){
				$PGprops = "" | Select Cluster, ESXiHost, vSwitch, Portgroup, VLAN, Setting, ActiveNIC, StandbyNIC, Device, Mac, DHCP, IP, SubnetMask, MTU, TsoEnabled, Policy, NotifySwitches, RollingOrder, ShapingEnabled, AverageBandwidth, PeakBandwidth, BurstSize
				$PGprops.Cluster = $Cluster
				$PGprops.ESXiHost = $($VMHost.Name)
				$PGprops.vSwitch = $vsw
				$PGprops.PortGroup = $pg.Name
				$PGprops.VLAN = $pg.VLanId
                if ($pg.extensiondata.spec.policy.Nicteaming.NicOrder.ActiveNic) {
                    $PGprops.Setting = "PG"
                    $PGprops.ActiveNIC = [string]::Join(',',$pg.extensiondata.spec.policy.Nicteaming.NicOrder.ActiveNic)}
                  else {
                    $PGprops.Setting = "vSw"}			
                if ($pg.extensiondata.spec.policy.Nicteaming.NicOrder.StandbyNic) {
                    $PGprops.Setting = "PG"
                    $PGprops.StandbyNIC = [string]::Join(',',$pg.extensiondata.spec.policy.Nicteaming.NicOrder.StandbyNic)}	
				if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.Device = $vNicTab[$pg.Name].Device}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.Mac = $vNicTab[$pg.Name].Spec.Mac}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.Dhcp = $vNicTab[$pg.Name].Spec.Ip.Dhcp}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.IP = $vNicTab[$pg.Name].Spec.Ip.IpAddress}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.SubnetMask = $vNicTab[$pg.Name].Spec.Ip.SubnetMask}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.MTU = $vNicTab[$pg.Name].Spec.Mtu}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.TsoEnabled = $vNicTab[$pg.Name].Spec.TsoEnabled}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.ShapingEnabled = $vNicTab[$pg.Name].Spec.Spec.Policy.ShapingPolicy.Enabled}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.AverageBandwidth = $vNicTab[$pg.Name].Spec.Spec.Policy.ShapingPolicy.AverageBandwidth}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.PeakBandwidth = $vNicTab[$pg.Name].Spec.Spec.Policy.ShapingPolicy.PeakBandwidth}
                if ($vNicTab.ContainsKey($pg.Name)) {$PGprops.BurstSize = $vNicTab[$pg.Name].Spec.Spec.Policy.ShapingPolicy.BurstSize}
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
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUErNCO2sdfyM7Wm/J/BdpNAd8
# wf+gggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUMZxRYfvwJGQX
# GFjZrb22yIumOOUwDQYJKoZIhvcNAQEBBQAEggEARLrw6rpJA/24M/iD+45dPWrU
# Fk2T0RnFENATqvfEDQOcWHVrP2hF6YCnpN0mHj0CTytd7283KANJ4N5X2cw37yAL
# V3uutG4m7wj4AQFnBpbUyH2DKJe5fIkfFcWxEF834rpPYYtRL7f08zkTzAL6dwSp
# AukVI48g6tVMzjjYi0yvtAx7BnDo/rCG9LoSKNMMg/C4f9zrGkaUuuQ6hDa7OZB0
# WleBUv5DgKJfxxDR8TamGoYfBeA5z/yIiMczCi7NfnQJNJve01iU9Xh7DslaGIB7
# 4R323PSMu6J7tWQTtPFECnimlgDyXwj2Ad6zLrFzF4wg4SIfP3AgrdbX/H1zAg==
# SIG # End signature block
