function Export-ESXiSWReleases {
<#
.SYNOPSIS
  Creates a csv file with ESXi Server's Package releases
.DESCRIPTION
  The function will export the ESXi server's SW packages releases and add them to a CSV file.
.NOTES
  Release 1.2
  Robert Ebneth
  March, 21st, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Cluster
  Selects only ESXi servers from this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.PARAMETER Filename
  Output filename
  If not specified, default is $($env:USERPROFILE)\ESXi_Pkgs_releases_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-ESXiSWReleases -Filename “C:\ESXi_swpkgs.csv”
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $False)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False)]
    [Alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\ESXi_Pkgs_releases_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
    $report = New-Object System.Collections.ArrayList
    $HostCount = 0

   	Write-Host ""
	Write-Host "Creating ESXi VIB Installation report..."
	Write-Host ""

} ### End Begin

Process {

	foreach ( $Cluster in $Cluster_from_input ) {
	$ClusterInfo = Get-Cluster $Cluster
    If ( $? -eq $false ) {
		Write-Host "Error: Required Cluster $($Cluster) does not exist." -ForegroundColor Red
		break
    }
    $ClusterHosts = Get-Cluster -Name $Cluster | Get-VMHost | Where { $_.PowerState -eq "PoweredOn" } | Sort Name | Select Name
    foreach ($esxihost in $ClusterHosts) {
        $esxcli = Get-EsxCli -VMHost $esxihost.Name
        $esxisw = $esxcli.software.vib.list($null) | select Name, Id, Version, InstallDate, Vendor, AcceptanceLevel
        foreach ( $instpkg in $esxisw ) {
            $swpkg = ""| select ClusterName, ESXiHost, PkgName, PkgId, PkgVersion, PkgInstallDate, PkgVendor, PkgAcceptanceLevel
            $swpkg.ClusterName = $ClusterInfo.Name
            $swpkg.ESXiHost = $esxihost.Name
            $swpkg.PkgName = $instpkg.Name
            $swpkg.PkgId = $instpkg.Id
            $swpkg.PkgVersion = $instpkg.Version
            $swpkg.PkgInstallDate = $instpkg.InstallDate
            $swpkg.PkgVendor = $instpkg.Vendor
            $swpkg.PkgAcceptanceLevel = $instpkgget.AcceptanceLevel
            [void] $report.Add($swpkg)
        }
        $HostCount++
    } ### End Foreach ESXi Host
    } ### End Foreach Cluster
} ### End Process

End {
    Write-Host "Writing ESXi SW Pkg info to file $($OUTPUTFILENAME)..."
    $report | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
    Write-Host ""
    #
    # Finally we give a small summary report
    # 
    Write-Host "Creating ESXi VIB Summary Report..."
    $SWPkgs = (($report | Select PkgId -Unique).PkgId | Sort)
    $VIBSummary = foreach ($Pkg in $SWPkgs) {
        $SRV_with_this_Pkg = $report | Where { $_.PkgId -eq "$Pkg" }
        if ( ! $($SRV_with_this_Pkg).Count ) { $VIB_Installed_Count = "1" }
            else {$VIB_Installed_Count = $($SRV_with_this_Pkg).Count}
        Select -InputObject $Pkg -Property @{N="VIB";E={$Pkg}},
            @{N="Installed VIBs";E={$VIB_Installed_Count}},
            @{N="Total Hosts";E={$HostCount}}
        } ### End Select
    $VIBSummary | Ft -AutoSize
    Write-Host "Creating ESXi VIB Differences Report..."
    $VIBDifferences = $VIBSummary | where { $_."Installed VIBs" -ne $HostCount }
    $VIBDifferences | Ft -AutoSize
} ### End End

} ### End function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUW/8v2nX+SbFvDscFkt8KAP1R
# ez2gggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUazZZPNZmNLfj
# Rg8mX1GzK+NBcKwwDQYJKoZIhvcNAQEBBQAEggEAaksymTJeY/Iskdmrja2hAKLC
# jNQAHoXs2zj1lUJTq0ZoghNnhVNnkf6/X0EQcDs/22sPIvS5T6K7l2+DhkNBDc0a
# 7jOtwgSpFA4T1ju6XtcpQm7d1uPC6ssedAjOgY1Cx0qYQ0V5HhdbSSaxw78krRO9
# sNIG8kp+OVsnVGmp8nT5XeNsgisLCzLXlBRZdX/yr7WxPRRDN84VS1xh7YTB72EJ
# xtiDkqXyEOpn6Qf9R8jrvXUabspNuDkOOVXSN5Uy4L1UTrIaQf49uVga7PdbaBZT
# 1O2x0MVaF3XNXmRLPo/ksHGiminQmdoQPEHegKewciVMqg0yuJo4WcNQs7imPA==
# SIG # End signature block
