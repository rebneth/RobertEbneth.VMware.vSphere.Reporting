function Get-ESXiScratchLocation {
<#
.SYNOPSIS
  Creates a csv file with ESXi Server's Scratch Location
.DESCRIPTION
  The function will export the ESXi server's Scratch Location.
.NOTES
  Release 1.4
  Robert Ebneth
  July, 12th
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
	[Parameter(Mandatory = $False, ValueFromPipeline=$true)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False)]
    [Alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\ESXi_Scratch_Location_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
        $ClusterHosts = Get-Cluster -Name $Cluster | Get-VMHost | Sort Name | Select Name, ExtensionData
        foreach($vmhost in $ClusterHosts) {
            Write-Host "Getting Scratch Location for Host $($vmhost.Name)..."
            $HostConfig = “” | Select Cluster, HostName, CurrentScratchLocation, Datastore, Type, SizeMB, FreeMB
            $HostConfig.Cluster = $Cluster
            $HostConfig.HostName = $vmhost.Name
            $HostConfig.CurrentScratchLocation = Get-VMhost -Name $vmhost.Name | Get-AdvancedSetting -Name "ScratchConfig.CurrentScratchLocation" | Select-Object -ExpandProperty Value
            $ESXCli = Get-EsxCli -VMHost $vmhost.Name
			$MountedFS = $ESXCli.storage.filesystem.list() | select VolumeName, UUID, MountPoint, Type, Size, Free
            $ScratchFS = $MountedFS | ?{ $HostConfig.CurrentScratchLocation  -Like "$($_.Mountpoint)*" }
            $HostConfig.Datastore = $ScratchFS.VolumeName
            $HostConfig.Type = $ScratchFS.Type
            #$HostConfig.SizeMB = [Math]::Round(($ScratchFS.Size/1024/1024), 0)
            #$HostConfig.FreeMB = [Math]::Round(($ScratchFS.Free/1024/1024), 0)
            # We add a thousands seperator
            # Used seperator depends on culture settings that canbe verified by
            # (Get-Culture).NumberFormat.NumberGroupSeparator
            $HostConfig.SizeMB = [string]::Format('{0:N0}',([Math]::Round(($ScratchFS.Size/1024/1024), 0)))
            $HostConfig.FreeMB = [string]::Format('{0:N0}',([Math]::Round(($ScratchFS.Free/1024/1024), 0)))
            $report+=$HostConfig
        } ### Foreach ESXi Host
    } ### End Foreach Cluster
} ### End Process

End {
    Write-Host "Writing ESXi scratch info to file $($OUTPUTFILENAME)..."
    $report | Export-csv -Delimiter ";" $OUTPUTFILENAME -Encoding UTF8 -noTypeInformation
    $report | FT -AutoSize
} ### End End

} ### End function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQURvWRnsW+95qpTiVQUJlpQLMm
# TDWgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUt42vmibzxtWs
# fXsDWHCP/D7gBcowDQYJKoZIhvcNAQEBBQAEggEACRJe1PAYEPo7+x8Fiyl5TZrO
# ngxAlLKDe1wjo+++6iLuLnBciU1g3IqPcHy9Ldyk6SkGpn3C7Hy6HSvYrFxyicZ/
# tSG2P+JCt4s/myjE4xs/tnL155Bd50mFoAiBhvueVTqs0JWfKCPUU4kRYLZ8Ougb
# 7PV2boORTC0XinFl2sJE5i9M4a1/f3McCXDBtsbycRGV7sZdxCPvBXZk9QLtVF0O
# CivJhEyZY1T3s8Evqns2fPCSh8GzWOtH6uo7efwIrQWZdRrJZ3l2Osey/iF1T4TF
# iWgMkLpyXuE1LzrRtQl1kRBehnUqSBp6YmSNHk4AQ6lXKSXryBnMygaxEcHtag==
# SIG # End signature block
