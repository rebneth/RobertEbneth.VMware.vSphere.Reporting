function CheckFilePathAndCreate {
<#
.Synopsis
   CheckFilePathAndCreate
.DESCRIPTION
   Checks Syntax of an Filepath, if Directory is Valid and creates this file if it does not exists
   If Filepath is empty or just a directory, a default Filename in a default Directory is used.
   This common function is used from vSphere Reporting Scripts
.NOTES
  Release 1.0
  Robert Ebneth
  January, 3rd, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Filename
.EXAMPLE
   CheckFilePathAndCreate DEFAULTFILENAME
.EXAMPLE
   CheckFilePathAndCreate DEFAULTFILENAME FILEPATH_TO_VAIDATE
#>

  #[CmdletBinding()]
  param(
   [Parameter(Mandatory = $True, ValueFromPipeline=$false, Position = 0,
   HelpMessage = "Enter the path to the output file")]
   [string]$FILENAME
  )

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
