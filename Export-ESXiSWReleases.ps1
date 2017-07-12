function Export-ESXiSWReleases {
<#
.SYNOPSIS
  Creates a csv file with ESXi Server's Package releases
.DESCRIPTION
  The function will export the ESXi server's SW packages releases and add them to a CSV file.
.NOTES
  Release 1.3
  Robert Ebneth
  July, 12th, 2017
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
	[Parameter(Mandatory = $False, ValueFromPipeline=$true)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False)]
    [Alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\ESXi_Pkgs_releases_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
    $report = New-Object System.Collections.ArrayList
    $HostCount = 0

   	Write-Host ""
	Write-Host "Creating ESXi VIB Installation report..."
	Write-Host ""

} ### End Begin

Process {

    # If we do not get Cluster from Input, we take them all from vCenter
	If ( !$Cluster ) {
		$Cluster_to_process = (Get-Cluster | Select Name).Name | Sort}
	  else {
		$Cluster_to_process = $CLUSTER
	}
    
	foreach ( $Cluster in $Cluster_to_process ) {
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
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUf9L8OcfoZ2m4o5oZfLmraZAL
# R9+gggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUBx1Byi7dhMnM
# 7uzol20gSGceNw8wDQYJKoZIhvcNAQEBBQAEggEAaRCJg5fUMkIbYGbioOQjDjfK
# ao8EPW8QJTOK046VZw74nhxNmxu7zcYaS/0dHBjAufxGSaO5Pn78dSkHijy4CBWe
# oa0RomlvoJP7zrvvs1EnKj6XpORxSei3ZSbuII26pmfBkYAdJrNExAtm0y/d5kMb
# /Ro3xc7vDX4QY9Xve+JHprhg01phe5opsSyWjYq0T/EypEWqO+G/FRXrQmRvpvvf
# OBn8kA1pvJJmiUy+Fqd9egOH1tjxjqxkZOts6TBjVOOtaqafXlHggKz+bClMJhFr
# 4OJGXEHFDXIa0ZXdzoGWQwgDyAIa3egNGJvsh6gVmc+85mVjpstydbzs+4u1WA==
# SIG # End signature block
