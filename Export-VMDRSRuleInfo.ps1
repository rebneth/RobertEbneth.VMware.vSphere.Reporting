function Export-VMDRSRuleInfo {
<#
.SYNOPSIS
  Creates a csv file with the information to which DRS Rule(s) this VM belongs to
.DESCRIPTION
  Creates a csv file with the information to which DRS Rule(s) this VM belongs to
.NOTES
  Release 1.0
  Robert Ebneth
  February, 16th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Cluster
  Selects only DRSRules/VMs from this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.PARAMETER Filename
  The path of the CSV file to use when exporting
  Default: $($env:USERPROFILE)\DRS_Rules_per_VM_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-VMDRSRuleInfo -Filename “C:\DRS_Rules_per_VM.csv”
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $False)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\DRS_Rules_per_VM_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv" 
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

# Step 1: Get all DRS Rules for this cluster
Write-Host "Collect all DRS Rules for vSphere Cluster $($CLUSTER)..."
$ALL_DRS_RULES = Get-DrsRule -Cluster $CLUSTER -Type @("VMAffinity", "VMAntiAffinity", "VMHostAffinity") | select Cluster, Enabled, Name, Type, `
@{N="VM";E={(Get-View $_.VMIDS | Select -ExpandProperty Name)}}, `
@{N="AffinityHosts";E={(Get-View $_.AffineHostIds | Select -ExpandProperty Name) }},`
@{N="Running on";E={(Get-View (Get-View $_.VMIds | %{$_.Runtime.Host}) | Select -ExpandProperty Name) }}

# Step 2: Foreach VM that is in each DRS Rule create an entry in an temporary tab that contains the DRS properties
Write-Host "Extract VMs from DRS Rules..."
$RulePerVMReport = @()
foreach ($DRSRULE in $ALL_DRS_RULES) {
    switch -Wildcard ($DRSRULE.Type) {
        VMHostAffinity {
            foreach ($vm in $DRSRULE.VM) {
                $VMRuleInfo = "" | Select Cluster, VMName, DRSRuleCount, DRSRule, DRSRuleType, PowerState, VMHost, AffinityHosts, Affinity_Antiaffinity_VMs
                $VMRuleInfo.Cluster = $CLUSTER
                $VMRuleInfo.VMName = $vm
                $VMRuleInfo.DRSRule = $DRSRULE.Name
                $VMRuleInfo.DRSRuleType = $DRSRULE.Type
                if ( $DRSRULE.AffinityHosts -ne "") { $VMRuleInfo.AffinityHosts = [string]::Join(',',$DRSRULE.AffinityHosts)}
                   else { $VMRuleInfo.AffinityHosts = "No Hosts specified" }
                $RulePerVMReport += $VMRuleInfo
            } ### End foreach VM
        } ### End Switch VMHostAffinity
        default {
            foreach ($vm in $DRSRULE.VM) {
                $VMRuleInfo = "" | Select Cluster, VMName, DRSRuleCount, DRSRule, DRSRuleType, PowerState, VMHost, AffinityHosts, Affinity_Antiaffinity_VMs
                $VMRuleInfo.Cluster = $CLUSTER
                $VMRuleInfo.VMName = $vm
                $VMRuleInfo.DRSRule = $DRSRULE.Name
                $VMRuleInfo.DRSRuleType = $DRSRULE.Type
                if ( $DRSRULE.VM -ne "") { $VMRuleInfo.Affinity_Antiaffinity_VMs = [string]::Join(',',$DRSRULE.VM)}
                   else { $VMRuleInfo.Affinity_Antiaffinity_VMs = "No VMs specified" }
                $RulePerVMReport += $VMRuleInfo
            }
        } ### End default
    } ### End Switch Switch
} ### End foreach DRS rule

# Step 3: We get all VMs per Cluster and check, if there is a DRS rule to this VM (from temporary tab)
foreach ($vm in (Get-Cluster -Name $CLUSTER | Get-VM | Where {$_.ExtensionData.Config.Template -eq $False }|Sort Name )) {
    Write-Host "Checking DRS Rules for VM $($vm)..."
    [Array]$DRSRulesInfo_per_VM = $RulePerVMReport | Where {$_.VMName -eq $vm.Name }
    if (! $DRSRulesInfo_per_VM) {
        $VMDRSInfo = "" | Select Cluster, VMName, DRSRuleCount, DRSRule, DRSRuleType, PowerState, VMHost, AffinityHosts, Affinity_Antiaffinity_VMs
        $VMDRSInfo.Cluster = $CLUSTER
        $VMDRSInfo.VMName = $vm
        $VMDRSInfo.DRSRuleCount = "0"
        # We add the VMHost and PowerState from current VM Info
        $VMDRSInfo.PowerState = $vm.PowerState
        $VMDRSInfo.VMHost = $vm.VMHost
        $report += $VMDRSInfo
        continue    
    }
    foreach ($VMDRSInfo in $DRSRulesInfo_per_VM) {
        # We add the VMHost and PowerState from current VM Info
        $VMDRSInfo.PowerState = $vm.PowerState
        $VMDRSInfo.VMHost = $vm.VMHost
        $VMDRSInfo.DRSRuleCount = $DRSRulesInfo_per_VM.Count
        $report += $VMDRSInfo
    } ### End Foreach DRS Rule per VM
    
} ### End Foreach VM

} ### End Foreach Cluster

} ### End Process

End {
    $report | FT -AutoSize
    Write-Host "Writing File $($OUTPUTFILENAME)..."
    $report | Export-Csv $OUTPUTFILENAME -NoTypeInformation -UseCulture
} ## End End
  
} ### End function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCkfwmltkmwUAbXxszGSMN5FW
# bQWgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU1jeSiJgHr9S+
# 2cHtSpF4AzCSv3MwDQYJKoZIhvcNAQEBBQAEggEAEieD6i2I2D4xRyhv3fEm0+gf
# Kbm3F7JyPe89ix91HWDHh6lb+v3tPVoYz5n5Wruh/RoqJvagrEK4LXim0CbymRei
# Uw73pwUc7zVtv/yN5jKJVOsFjCSMKDaFHMjFrrpFQsE9wkiFWirEVXkg7eMQG2s5
# WFKGHRsgmItbjsiaVRbk+4pvW9zwyonQSZBGHliVg+IvV6FXlFde33QDje5HkVbK
# H5XQCZHawUFgWV6kraWgefDSShnpHqa6ByKX6DTmG2oUwLdRJD3IMDuJa8xJ1ZJF
# po3GRDLAImp6wGJ0JDbmGlckf1JFntTMvrHaVBWnqr5IRCIk480/wFnpKMRbdg==
# SIG # End signature block
