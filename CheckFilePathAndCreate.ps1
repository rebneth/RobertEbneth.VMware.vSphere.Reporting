function CheckFilePathAndCreate {
<#
.Synopsis
   CheckFilePathAndCreate
.DESCRIPTION
   Checks Syntax of an Filepath, if Directory is Valid and creates this file if it does not exists
   If Filepath is empty or just a directory, a default Filename in a default Directory is used.
   This common function is used from vSphere Reporting Scripts
.NOTES
  Release 1.1
  Robert Ebneth
  February, 4th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER FILENAME
  Path and Filename for outputfile (csv) that has to be checked
.EXAMPLE
  CheckFilePathAndCreate TFILENAME
#>

param(
    [Parameter(Mandatory = $True, ValueFromPipeline=$false, Position = 0,
    HelpMessage = "Enter the path to the output file")]
    [string]$FILENAME
)

# Default Filename is empty
$OUTPUTFILENAME = ""

switch -wildcard ($FILENAME) 
    { 
        ".\*" {
                $FILENAME = $FILENAME.remove(0,2)
                $WORK_DIR = Get-Location
                $OUTPUTFILENAME = "$($WORK_DIR)\$($FILENAME)"} 
        "..\*" {
                $FILENAME = $FILENAME.remove(0,3)
                $WORK_DIR = Split-Path -parent (Get-Location)
                $OUTPUTFILENAME = "$($WORK_DIR)\$($FILENAME)"}  
        default {
                $DriveLetter = Split-Path $FILENAME -Qualifier -ErrorAction SilentlyContinue 
                if ($?) { 
                    # $FILENAME contains Drive Letter
                    if ($FILENAME -eq $DriveLetter) {
                        write-Error "Filename contains only drive letter"; break}
                    $FILENAMEPART = Split-Path $FILENAME -Leaf
                    if ($FILENAMEPART -eq "$($DriveLetter)\") {
                        write-Error "Filename contains only drive letter and \"; break}
                    $OUTPUTFILENAME = $FILENAME
                    }
                  else {
                    # $FILENAME contains NO Drive Letter
                    $FILENAMEPART = Split-Path $FILENAME -Leaf
                    if ( "$FILENAMEPART" -eq "$FILENAME" ) {
                        $WORK_DIR = Get-Location
                        $OUTPUTFILENAME = "$($WORK_DIR)\$($FILENAME)"}
                      else {
                        # drirecory\filename in the current still not supported
                        $WORK_DIR = Get-Location
                        $OUTPUTFILENAME = "$($WORK_DIR)\$($FILENAME)"
                        #Split-Path -Parent $
                        break}    
                    }
                } ### End default
           
    } ### End Switch statement

if ( $OUTPUTFILENAME -ne "" ) {
    # Now we check, if the Directory within the $FILENAME does exist
    $DirectoryPath = Split-Path $OUTPUTFILENAME -ErrorAction SilentlyContinue
    if ((Test-Path $DirectoryPath) -eq $False) { Write-Error "Directory does not exist: $DirectoryPath"; break}
    # Now we check, if the $FILENAME does exist
    if ((Test-Path $OUTPUTFILENAME) -eq $True)
    	{Remove-Item $OUTPUTFILENAME}
    New-Item $OUTPUTFILENAME -type file | out-null
    if (!$?) {
        Write-Error "Output File $OUTPUTFILENAME could not be created"; break
    }
    $OUTPUTFILENAME}
  else {
    break}

} ### End Function

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUm0YR3FyylnQKp0mQOx1UyRMT
# aZGgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUbQlWgp9HZimL
# vbVTi/3DZGVuLIQwDQYJKoZIhvcNAQEBBQAEggEAXSenUm5+W3b0EP3Xs/l/Q1FY
# 8aG8loOIcyb5ml2d+gFRDrzXtj7lVpP28w9Io14BPbCHslWD3mcOA235kydl7JXK
# s19TIs/QKbxEB6x5z/dFhoUPIhAgPjJpiGL7nMiwKcrhoQXmn8S11vFJ7U9pfy8+
# kshQnTwHolUYQT9ktazZE41WF8BNNaL8vp+PYT42sRihtIHaaXPXJSKT1IBitdvv
# sulzEi4BV/q62+j/VsC0Mia1eBpehiftPW1TeUaUTqR5nyUze4oZ2aTgzejCPxq/
# Tvj98IsLvd6EgjJmfPWkMhIewk6osgENjwCISe73WE+mjm9ca15Mes5OPZk8BA==
# SIG # End signature block
