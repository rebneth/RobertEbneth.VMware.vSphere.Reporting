function Export-VMDRSRuleInfo {
<#
.SYNOPSIS
  Creates a csv file with the information to which DRS Rule(s) this VM belongs to
.DESCRIPTION
  Creates a csv file with the information to which DRS Rule(s) this VM belongs to
.NOTES
  Release 1.1
  Robert Ebneth
  July, 12th, 2017
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
	[Parameter(Mandatory = $False, ValueFromPipeline=$true)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\DRS_Rules_per_VM_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv" 
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
	$OUTPUTFILENAME = CheckFilePathAndCreate "$FILENAME"
    $report = @()

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
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU42sXbk6f9HezyuV5M03teeJz
# Ks2gggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU+aNugx1gmVX0
# a8G2LdT2mWr/HhowDQYJKoZIhvcNAQEBBQAEggEAYbjOHPhRV49+LsO1xnx/zHyT
# JN0JmD5rFVEnB71845D9xNSUDzXxpkzAwqiAi+tCHLaNEyAqxyWhUc0NFrMeVt/h
# khrC+PhYh/FUDfa3BJ2FKmmLr4p3o/46I+W8aOhTvO/oh0metYSCgYrJ4+XsoRu6
# iTCnesvWtQlV40AJ4XpJNsp4+TohDe5BTVdGV/TiyUTe/I+P1/Up5hDdz5oufg8j
# E1QpiJz3yYPTMyKVpx06gPCTIIcMMCrGCrV0YnDK6G6ZjIssizXVmB25R1JGS6Oi
# 24F4homDjQaFNM1RctQXdxn6GFs60laHrijbFr0u+y76piz1fQSPEIyzCdtBSQ==
# SIG # End signature block
