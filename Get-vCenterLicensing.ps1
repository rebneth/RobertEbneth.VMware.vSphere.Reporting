function Get-vCenterLicensing {
<#
.SYNOPSIS
  Creates a csv file with the vCenter Licensing information
.DESCRIPTION
  Creates a csv file with the vCenter Licensing information
.NOTES
  Release 1.2
  Robert Ebneth
  July, 12th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Filename
  The path of the CSV file to use when exporting
  Default: $($env:USERPROFILE)\vCenterLicensing_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Get-vCenterLicensing [ -FILENAME d:\licensing.csv ]
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $False, Position = 0)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\vCenterLicensing_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)

########
# Main #
########

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

# Get License keys ( this is needed to show up which vSphere Edition is activated by the License key)
$servInst = Get-View ServiceInstance
$licMgr = Get-View $servInst.Content.LicenseManager
$licMgr.Licenses | Select Name, CostUnit, LicenseKey, Total, Used | Sort Name | Format-Table

Write-Host "Writing Outputfile $($OUTPUTFILENAME)..."
$licMgr.Licenses | Select Name, CostUnit, LicenseKey, Total, Used | Sort Name | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation 

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPPckef0fFQKD+wBi0X2kNgts
# thOgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUH9Zs28vLx1dO
# LiCZyKmbrnKfbQMwDQYJKoZIhvcNAQEBBQAEggEART5tte30UujoVyE2S6143kuY
# ja79tG7DjBPWmHRYKG8WVeGp1TGMPMn/B7GuNSc3vN9PB7/lezfvqcZkL2X7PhN6
# SKuWaxOgVMbDTPfV9GPkC+cgrFSqLb+Q/ovTKdS0Fg5dHTprjQs1u3pODnVa/ASf
# pv2anTGb7Aklraw4C39SPtKCSwDXp9rFEpMsHNwwfbl1K+fjDxtI2aitmFpbfotC
# VDuJzU7cQ++G6JEI8EXEOHspSnRU0Hgd3dX6z4k6+T62zEToK9v+LPoBPV50scL+
# xbqkibeDT0aXLv11PH2qoEejoTcSa8+eTfTFjOB+n2d5ezrIVsqs1OeYRFHBLw==
# SIG # End signature block
