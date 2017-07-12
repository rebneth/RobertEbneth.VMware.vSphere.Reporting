function Export-DatastoreProps {
<#
.SYNOPSIS
  Creates a csv file with the properties of all datastores
.DESCRIPTION
  Creates a csv file with the properties of all datastores
  this covers Datastore, VMCount, Capacity, FreeSpace, CommittedPercent
.NOTES
  Release 1.2
  Robert Ebneth
  July, 12th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Filename
  The path of the CSV file to use when exporting
  Default: $($env:USERPROFILE)\Datastore_Overcommitment_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-DatastoreProps `
      -Filename �C:\DSprops.csv�
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $FALSE)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\Datastore_Overcommitment_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
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
	$OUTPUTFILENAME = CheckFilePathAndCreate $FILENAME
    $report = @()
} ### End Begin

Process {
  
    ########
    # Main #
    ########

    $DatastoreInfo = Get-Datastore | ForEach-Object {
      $Datastore = $_.Extensiondata
      if ($Datastore.Summary.Uncommitted -gt "0") {
        $DS = "" | Select-Object -Property Datastore, VMCount, Capacity, FreeSpace, CommittedPercent
        $DS.Datastore = $Datastore.name
	    $DS.Capacity = [math]::round(($Datastore.Summary.Capacity/1024/1024/1024), 2)
	    $DS.FreeSpace = [math]::round(($Datastore.Summary.FreeSpace/1024/1024/1024), 2)
        $DS.CommittedPercent = [math]::round(((($Datastore.Summary.Capacity - $Datastore.Summary.FreeSpace) + $Datastore.Summary.Uncommitted)*100)/$Datastore.Summary.Capacity,0)
 	    $DS.VMCount = $Datastore.VM.Count
	    $DS
      } ### End If
    } ### End Foreach Object

    #$DatastoreInfo | Sort-Object CommittedPercent -Descending
    #$DatastoreInfo | % { $_.CommittedPercent = [int]$_.CommittedPercent } 
    $report += $DatastoreInfo

} ### End Process

End {
    Write-Host "Writing Output File $($OUTPUTFILENAME)..."
    $report | Sort-Object CommittedPercent -Descending | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
} ### End End

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU8AGU7QzquHoIWSAUZXnH0zeY
# qZigggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUYo7WnKh7jIoH
# i83DCxF5gqBOggowDQYJKoZIhvcNAQEBBQAEggEAmDUH0J+cPsP9VKGXEWfLshgP
# MYTxki1OG5uC/1kjiTR/P4ElLsv/B3MVuIREjIeQoaKsBIAaKM94nwNTZW6i710l
# 48HXwbeM9xZLxYHc1WXNrRPIcAuaFzFezHHY8JgCdbOVblFtUKVYV17aK5KzRJfG
# ytOBC2oge7hwTQbWSUXqxIZU75WBnhgLwuQ9ADPVmHrcwkrCjByrtwtF9KM27EmJ
# PU1aGrkOB1wFZ36wlGBSN9Ar1Titw+7K6coSedXLyJ6XL/oB1IwgmE/CkqKIOuRR
# GMFMrltl6tJjm9OTI3u1tq5s5KgkcG1miCSQo2jekM7zso4Q5bf22fc8UocX+w==
# SIG # End signature block
