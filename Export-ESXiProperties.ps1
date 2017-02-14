function Export-ESXiProperties {
  <#
.SYNOPSIS
  Creates a csv file with the Properties of VMware ESXi Servers
.DESCRIPTION
  The function will export the Properties of VMware ESXi Servers from vCenter Server and add them to a CSV file.
.NOTES
  Release 1.1
  Robert Ebneth
  February, 9th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Filename
  Output filename
  If not specified, default is $($env:USERPROFILE)\vSphere_VC_and_ESXi_release_inventory.csv
.EXAMPLE
  Export-ESXiProperties`
      -Filename “C:\ESXi_props.csv”
#>
 
[CmdletBinding()]
param(      
    [Parameter(Mandatory = $False, ValueFromPipeline=$false)]
    [alias("e")]
    [switch]$extendedmode = $true,
    [Parameter(Mandatory = $false, Position = 1)]
    [Alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\ESXi_Properties_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
	#Change powercliconfiguration so SSL cert errors will be ignored
	# Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

	$vcversion = $global:DefaultVIServers | Select -ExpandProperty Version
	$vcbuild = $global:DefaultVIServers | Select -ExpandProperty Build

    # Get License keys ( this is needed to show up which vSphere Edition is activated by the License key)
    $servInst = Get-View ServiceInstance
    $licMgr = Get-View $servInst.Content.LicenseManager
    #$licMgr.Licenses

    $OUTPUTFILENAME = CheckFilePathAndCreate $FILENAME
    # temporary memory table for output
	$AllHostInfo = @()

    Write-Host ""
    Write-Host "Datacollection for vCenter and ESXi server release and hardware information..."
    Write-Host ""

	# vCenter information
	$vCInfo = "" | Select VCversion, VCBuild, Datacentername, Clustername, HostName, ESXiEdition, ESXiVersion, ESXiBuild, HostManufacturer, HostModell, HostBiosVersion, HostBiosReleaseDate, ProcessorType, NumCpus, NumCpuCores, NumCpuThreads, CpuTotalMhz, CpuUsageMhz, CpuUsagePCT, MemoryTotalGB, VMMemoryAssignedGB, OverCommitGB, MemoryUsageGB, MemoryUsagePCT, HBA_String, LicenseKey, CpuPowerManagementCurrentPolicy, ConnectionState, PowerState, BootTime
	$vCInfo.VCversion = $vcversion
	$vCInfo.VCBuild = $vcbuild
	# head line info for each vCenter
	$AllHostInfo += $vCInfo

} ### End Begin

Process {

    ########
    # Main #
    ########

    Foreach ( $DataCenter in Get-DataCenter) {
      # 2nd level loop: for each Cluster in Datacenter
	  FOREACH ($VMcluster in Get-Datacenter $DataCenter.Name | Get-Cluster | Sort-Object Name) {
		# 3rd level loop: for each esxi host in cluster
		FOREACH ($vmhost in (get-cluster $VMcluster | get-vmhost | Sort-Object Name)) {
            Write-Host "Collecting information for ESXi host $($VMHost.Name)..."	
			$HostInfo = "" | Select VCversion, VCBuild, Datacentername, Clustername, HostName, ESXiEdition, ESXiVersion, ESXiBuild, HostManufacturer, HostModell, HostBiosVersion, HostBiosReleaseDate, ProcessorType, NumCpus, NumCpuCores, NumCpuThreads, CpuTotalMhz, CpuUsageMhz, CpuUsagePCT, MemoryTotalGB, VMMemoryAssignedGB, OverCommitGB, MemoryUsageGB, MemoryUsagePCT, HBA_String, LicenseKey, CpuPowerManagementCurrentPolicy, ConnectionState, PowerState, BootTime
			$HostInfo.VCVersion = $vcversion
			$HostInfo.VCBuild = $vcbuild
			$HostInfo.Datacentername = $DataCenter.Name
			$HostInfo.Clustername = $VMcluster.Name
			$HostInfo.HostName = $vmhost.Name
            $HostInfo.ESXiEdition = $licMgr.Licenses | Where { $_.LicenseKey -eq $($vmhost.LicenseKey) } | Select-Object -ExpandProperty Name
			$HostInfo.ESXiVersion = $vmhost.Version
			$HostInfo.ESXiBuild = $vmhost.Build
			$HostInfo.HostManufacturer = $vmhost.Manufacturer
			$HostInfo.HostModell = $vmhost.Model
			if ( $EXTENDEDMODE -eq $True ) {
                $HBA_INFO = Get-VMHostHba -VMHost $vmhost | Where { ($_.Type -Like "IScsi") -or ( $_.Type -Like "FibreChannel") } | Select Device, Model, Status | Sort Device
                $HBA_String = ""
                $hbacount = 1
                foreach ($hba in $HBA_Info) {
                    $HBA_String = "$($HBA_String)$($hba.Device);$($hba.Model);$($hba.Status)"
                    if ( $hbacount -lt $HBA_Info.Length ) { $HBA_String = $HBA_String + " # "; $hbacount++ }
                }
				$HostInfo.HostBiosVersion = $vmhost.ExtensionData.Hardware.BiosInfo.BiosVersion
				$HostInfo.HostBiosReleaseDate = $vmhost.ExtensionData.Hardware.BiosInfo.ReleaseDate
				$HostInfo.ProcessorType = $vmhost.ProcessorType
				$HostInfo.NumCpus = $vmhost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
				$HostInfo.NumCpuCores = $vmhost.ExtensionData.Hardware.CpuInfo.NumCpuCores
				$HostInfo.NumCpuThreads = $vmhost.ExtensionData.Hardware.CpuInfo.NumCpuThreads
				$HostInfo.CpuTotalMhz = $vmhost.CpuTotalMhz
				$HostInfo.CpuUsageMhz = $vmhost.CpuUsageMhz
				[decimal]$PCT = [math]::round(($($HostInfo.CpuUsageMhz)/$($vmhost.CpuTotalMhz)), 2)
				$HostInfo.CpuUsagePCT = "{0:P0}" -f $PCT
				$HostInfo.MemoryTotalGB = ([decimal]::round($vmhost.MemoryTotalGB))               
                if ($VMMem) { Clear-Variable VMMem }
                $VM = Get-VMHost -Name $vmhost | Get-VM
                $VM | ?{$_.VMHost.Name -eq $VMHost.Name} | Foreach { [INT]$VMMem += $_.MemoryMB	}
                $HostInfo.VMMemoryAssignedGB = [Math]::Round(($VMMem/1024), 0)
                If ([Math]::Round(($VMMem - $VMHost.MemoryTotalMB), 0) -gt 0) {
                     $HostInfo.OverCommitGB = [Math]::Round((($VMMem - $VMHost.MemoryTotalMB)/1024), 0)}
				$HostInfo.MemoryUsageGB = ([decimal]::round($vmhost.MemoryUsageGB))
				[decimal]$PCT = [math]::round(($($vmhost.MemoryUsageGB)/$($vmhost.MemoryTotalGB)), 2)
				$HostInfo.MemoryUsagePCT = "{0:P0}" -f $PCT
				$HostInfo.HBA_String = $HBA_String
                $HostInfo.LicenseKey = $vmhost.LicenseKey
				$HostInfo.CpuPowerManagementCurrentPolicy = $vmhost.ExtensionData.Hardware.CpuPowerManagementInfo.CurrentPolicy
				$HostInfo.ConnectionState = $vmhost.ConnectionState
				$HostInfo.PowerState = $vmhost.PowerState
				$HostInfo.BootTime = $vmhost.ExtensionData.Summary.Runtime.BootTime
			  }
			$AllHostInfo += $HostInfo
			} # End Foreach ESXi Host
		  } # End Foreach Cluster
    } ### End Foreach Datacenter
} ### End Process

End {
    Write-Host "Writing Outputfile $($OUTPUTFILENAME)..."
	if ( $EXTENDEDMODE -eq $True ) {
		$AllHostInfo | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation}
	   else	{
	    $AllHostInfo | select VCversion, VCBuild, Datacentername, Clustername, HostName, ESXiEdition, ESXiVersion, ESXiBuild, HostManufacturer, HostModell | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation}
} ### End End

} ### End Function

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXRhHP99rbI7GQsmPSdXGgQTs
# f1WgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8JG2bYyF+h0D
# xsssrku0tZ99+1AwDQYJKoZIhvcNAQEBBQAEggEAIN2LKxfhu/PZFdAxuM7DPGNL
# ySYo98hdilAe/LJ/Mw54mbo8UIZbZ4BciQJsqtlOaIxzxAVa+VB8SGKzHCFHdGhC
# xtkAmgu6CN4p84N3MAQ5rHlymybUYM0I3RuT5CmnpP0PRlhK4mFY1SDcMB3xNvzJ
# 3OqoYRl2p1vfwl6mTA+rNq20Z459IvXlqMhXM+AI91w0DyGDkaeUxuu+0s2PAQlz
# 8V2KlilTG0QOsrro8Vt+47ITj9jcGYMvHnSLFkH5tpGpKG8ZApGIrtRcvhD8bRcR
# wv50uXVq+RykiwptzTiiZPcEob1UJagmpfQe1aXCeuy0ldwTZJ+9VdCiWZ63bQ==
# SIG # End signature block
