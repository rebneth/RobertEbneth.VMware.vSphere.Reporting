function Get-ESXiScratchLocation {
<#
.SYNOPSIS
  Creates a csv file with ESXi Server's Scratch Location
.DESCRIPTION
  The function will export the ESXi server's Scratch Location.
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
  Output filename
  If not specified, default is $($env:USERPROFILE)\ESXi_Scratch_Location_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Get-ESXiScratchLocation -Filename “C:\ESXi_Scratch_Location.csv”
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $False)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False)]
    [Alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\ESXi_Scratch_Location_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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

	foreach ( $Cluster in $Cluster_from_input ) {
	    $ClusterInfo = Get-Cluster $Cluster
        If ( $? -eq $false ) {
		    Write-Host "Error: Required Cluster $($Cluster) does not exist." -ForegroundColor Red
		    break
        }
        $ClusterHosts = Get-Cluster -Name $Cluster | Get-VMHost | Sort Name | Select Name, ExtensionData
        foreach($vmhost in $ClusterHosts) {
            Write-Host "Getting Scratch Location for Host $($vmhost.Name)..."
            $HostConfig = “” | Select Cluster, HostName, ScratchLocation, Datastore, Type, SizeMB, FreeMB
            $HostConfig.Cluster = $Cluster
            $HostConfig.HostName = $vmhost.Name
            $HostConfig.ScratchLocation = Get-VMhost -Name $vmhost.Name | Get-AdvancedSetting -Name "ScratchConfig.ConfiguredScratchLocation" | Select-Object -ExpandProperty Value
            $ESXCli = Get-EsxCli -VMHost $vmhost.Name
			$MountedFS = $ESXCli.storage.filesystem.list() | select VolumeName, UUID, MountPoint, Type, Size, Free
            $ScratchFS = $MountedFS | ?{ $HostConfig.ScratchLocation  -Like "$($_.Mountpoint)*" }
            $HostConfig.Datastore = $ScratchFS.VolumeName
            $HostConfig.Type = $ScratchFS.Type
            $HostConfig.SizeMB = [Math]::Round(($ScratchFS.Size/1024/1024), 0)
            $HostConfig.FreeMB = [Math]::Round(($ScratchFS.Free/1024/1024), 0)
            $report+=$HostConfig
        } ### Foreach ESXi Host
    } ### End Foreach Cluster
} ### End Process

End {
    Write-Host "Writing ESXi scratch info to file $($OUTPUTFILENAME)..."
    $report | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
    $report | FT -AutoSize
} ### End End

} ### End function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBv2x2TO2Az+/ElJFhC43Mf9Y
# +WmgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUqv2XhbEqDzV0
# W5bkn20gWrkzVbUwDQYJKoZIhvcNAQEBBQAEggEAB5HprrchKuQmtCmeHVOMfFTs
# ruqwSHFiI1w41t1FeK5HXDDCUKTtRPr5mY5k1sgBGF+mTVeDCb3hKsDMZF855cUv
# BZ7Q5lSw4F81qSCcjluJMwYRvwcStQXokrkFAWRcYto6aIhCm+8dM9V13dZ3ajbN
# 5iGI11QPa/lODBi6VSgCukWXJYfZDKz1mX19bTZouh9Q2RTJJEsOR+cE6u9KzmRr
# dpkmZPd4bLTAa3lmiUt5UW9th5uO4OC/eG1Ki7PKVkgoNM6NZ7J4/aFJWT9crFqz
# WS6Bv9EpZNSzfigw2hzS5Tiy8TjZakQRTJKIdw1veakeLDPu2cAVqzMjAh+uGw==
# SIG # End signature block
