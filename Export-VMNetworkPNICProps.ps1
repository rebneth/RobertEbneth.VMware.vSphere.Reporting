function Export-VMNetworkPNICProps {
<#
.SYNOPSIS
  Creates a csv file with the Events from vSphere Environment
.DESCRIPTION
  The function will export the Events from vSphere Environment
  and add them to a CSV file.
.NOTES
  Release 1.3
  Robert Ebneth
  April, 19th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Filename
  The path of the CSV file to use when exporting
  DEFAULT: $($env:USERPROFILE)\VMNicPnic_Details_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-VMNetworkPNICProps -FILENAME d:\vmnic_props.csv
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $False, Position = 0)]
	[Alias("c")]
	[string]$CLUSTER,
	[Parameter(Mandatory = $False, Position = 1)]
	[alias("f")]
	[string]$FILENAME = "$($env:USERPROFILE)\VMNicPnic_Details_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
) ### End Param

Begin {
    # We need the common function CheckFilePathAndCreate
    Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
    if ( $? -eq $false) {
        Write-Error "Function CheckFilePathAndCreate is missing."
        break
    }
	Import-Module VMware.VimAutomation.Vds  
	# If we do not get Cluster from Input, we take them all from vCenter
	If ( !$Cluster ) {
		$Cluster_from_Input = (Get-Cluster | Select Name).Name | Sort}
	  else {
		$Cluster_from_Input = $CLUSTER
	}
	$OUTPUTFILENAME = CheckFilePathAndCreate "$FILENAME"
    $report = New-Object System.Collections.ArrayList
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
	
	$Esxihosts = Get-Cluster -Name $cluster | Get-VMHost | Where-Object {$_.ConnectionState -eq "Connected"} | Sort Name 
	foreach ($Esxihost in $Esxihosts) {
        Write-Host "Collecting NIC information for ESXi host $($Esxihost.Name)..."  
		$Esxcli = Get-EsxCli -VMHost $Esxihost  
		$Esxihostview = Get-VMHost $EsxiHost | get-view  
		$NetworkSystem = $Esxihostview.Configmanager.Networksystem  
		$Networkview = Get-View $NetworkSystem  
       
		$DvSwitchInfo = Get-VDSwitch -VMHost $Esxihost
		if ($DvSwitchInfo -ne $null) {  
			$DvSwitchHost = $DvSwitchInfo.ExtensionData.Config.Host  
			$DvSwitchHostView = Get-View $DvSwitchHost.config.host  
			$VMhostnic = $DvSwitchHostView.config.network.pnic  
			$DVNic = $DvSwitchHost.config.backing.PnicSpec.PnicDevice  
		}  
     
		$VMnics = $Esxihost | get-vmhostnetworkadapter -Physical   #$_.NetworkInfo.Pnic  
		Foreach ($VMnic in $VMnics){  
			$realInfo = $Networkview.QueryNetworkHint($VMnic)
			$pNics = $esxcli.network.nic.list() | where-object {$_.name -eq $VMnic.name} | Select-Object AdminStatus, Description, Driver, Link, MTU           
			$Description = $esxcli.network.nic.list()  
			$CDPextended = $realInfo.connectedswitchport
			if ($vmnic.Name -eq $DVNic) {  
				$vSwitch = $DVswitchInfo | where-object {$vmnic.Name -eq $DVNic} | select-object -ExpandProperty Name
				}  
			  else {  
				$vSwitchname = $Esxihost | Get-VirtualSwitch | Where-object {$_.nic -eq $VMnic.DeviceName}  
				$vSwitch = $vSwitchname.name  
			}
            $FW_Driver_Info = $ESXCli.network.nic.get("$VMnic")
		    $NICdetails = New-Object PSObject
       		$NICdetails | Add-Member -Name Cluster -Value $Cluster -MemberType NoteProperty 
		    $NICdetails | Add-Member -Name EsxName -Value $esxihost.Name -MemberType NoteProperty  
    		$NICdetails | Add-Member -Name VMNic -Value $VMnic -MemberType NoteProperty  
	    	$NICdetails | Add-Member -Name vSwitch -Value $vSwitch -MemberType NoteProperty  
		    $NICdetails | Add-Member -Name MacAddress -Value $vmnic.Mac -MemberType NoteProperty
    		$NICdetails | Add-Member -Name AdminStatus -Value $pNics.AdminStatus -MemberType NoteProperty
	    	$NICdetails | Add-Member -Name Link -Value $pNics.Link -MemberType NoteProperty  
		    $NICdetails | Add-Member -Name SpeedMB -Value $vmnic.ExtensionData.LinkSpeed.SpeedMB -MemberType NoteProperty  
    		$NICdetails | Add-Member -Name Duplex -Value $vmnic.ExtensionData.LinkSpeed.Duplex -MemberType NoteProperty  
	    	$NICdetails | Add-Member -Name MTU -Value $pNics.MTU -MemberType NoteProperty
		    $NICdetails | Add-Member -Name Pnic-Vendor -Value $pNics.Description -MemberType NoteProperty  
    		$NICdetails | Add-Member -Name Pnic-drivers -Value $pNics.Driver -MemberType NoteProperty  
	    	$NICdetails | Add-Member -Name PCI-Slot -Value $vmnic.ExtensionData.Pci -MemberType NoteProperty
		    $NICdetails | Add-Member -Name VMNicFW -Value $FW_Driver_Info.DriverInfo.FirmwareVersion -MemberType NoteProperty
    		$NICdetails | Add-Member -Name VMNicVersion -Value $FW_Driver_Info.DriverInfo.Version -MemberType NoteProperty  
	    	$NICdetails | Add-Member -Name Device-ID -Value $CDPextended.devID -MemberType NoteProperty 
		    $NICdetails | Add-Member -Name Hardware-Platform -Value $CDPextended.HardwarePlatform -MemberType NoteProperty  
    		$NICdetails | Add-Member -Name PortNo -Value $CDPextended.PortId -MemberType NoteProperty 
	    	$NICdetails | Add-Member -Name Switch-IP -Value $CDPextended.Address -MemberType NoteProperty
		    $NICdetails | Add-Member -Name SoftwareVersion -Value $CDPextended.SoftwareVersion -MemberType NoteProperty 
		    [void] $report.Add($NICdetails)  
		}  ### End Foreach VMNIC

	} ### End Foreach ESXiHost

 } ### End Foreach Cluster
 
} ### End Process

End {
	$report | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
    Write-Host "Writing Outputfile $($OUTPUTFILENAME)..."
	$report | Sort-Object cluster, esxname, vmnic | Select EsxName, VMNic, Pnic-Vendor, Pnic-drivers, MacAddress, AdminStatus, Link, SpeedMB | ft *
} ### End End

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU4K6zFmOdpU139mUSLqnCec9B
# 66ugggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU/drKyBE7McOy
# khnCruTcnpGW/QMwDQYJKoZIhvcNAQEBBQAEggEAQvV1+ShHbrvsSrF6oEkvA0qs
# L1bKEzjKTNcQG5a3e9w5ppPf1DvdDRcUlYqmumHatLST42prMEWEnfa+HGzOuslJ
# 7m4F/4GT3lHjHfw7MsY4XzbZMzxtIeOx/7Eq1AC33BblVj8Ifzz8kHZRDDLFOsoO
# MwTvPAzZSqCLIUP0MZwKLCIBciyF3FADo2RM8x/pCs0AMDPvejkzTXyPuL1LcsdD
# PUm+XtmTLYe0JUwE3k2eieNTOzGdFDawUd6gvUbvShthxryXi1Aa+834JcbMNaVY
# BfLXze8zEoM+Lbxm+BON112gCmGlPjV0Q3nSlp6HNX6Y/yLDXxL0OhRxODwfZw==
# SIG # End signature block
