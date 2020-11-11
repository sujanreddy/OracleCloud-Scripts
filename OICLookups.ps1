<#
####################################################################################################
# File      : DevOpsOICS_Lookups.ps1                          
# Author    : Sujan Gutha                                    
# Created   : 01/23/2020                                           
#                                                                  
# Usage	: This powershell script will migrate the Lookups for OICS Integration. 
          This Scripts presently covers the following senarios.
          - If manifest file is specified while creating release, script will execute files mentioned in the file in sequence
            the manifest file sequence. 
          - if a single lookup is provided, it will still migrate depending on the extension
#                                                                  #
# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
#-------------------              ----------            -------------------------  
# Sujan Gutha                      12/30/2019              Initial Version
#
######################################################################################################
#>


#Reading the Variable values at run time during creation of release.
param(
  [string]$user,
  [string]$pass
)

try
{
#Accessing the variables from Release pipeline/variable groups. 
$url = "$env:url"
$ext = "$env:ext"
$manifest_dir = "$env:manifest_dir"
$Manifest_file = "$env:Manifest_file"

  #Set the Variable with the Cloned repository Path.
  $working_dir = "$env:System_DefaultWorkingDirectory\_$env:Build_DefinitionName"
  Write-Host "currnt Working dir $working_dir"

  #check for user input for manifest file. If file not entered fail the job.
  if ([string]::IsNullOrEmpty($Manifest_file))
  {
    Write-Host "Please enter the manifest file name in variable section"
    Write-Host "##vso[task.logissue type=error]Please enter the manifest file name in variable section"
    exit 1
  }

  #Check the Inputed Manifest files present in the Manifest folder in the git if not exit job.
  $check_manifestfile = Test-Path -Path $working_dir\$manifest_dir\$Manifest_file -PathType Leaf

  $check_Manifestext = [System.IO.Path]::GetExtension($Manifest_file)
     write-host "`n Checking file extension $check_Manifestext"
  if(!$check_manifestfile)
  {
    #Write-Host "The given manifest file is not present in the Manifest directory"
    Write-Host "##vso[task.logissue type=error]The given manifest file is not present in the Manifest directory"
    exit 1
  }

  #Read the Manifest file content and palce it array and Remove any commented lines and empty lines if any from manifest.
  $file_read_seq = Get-Content -Path $working_dir\$manifest_dir\$Manifest_file | Where {$_ -notmatch '^--.*'}
  $file_seq = $file_read_seq.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
  Write-Host "The sequence is $file_seq "
 
  # check for FileExtenions if .pks,pkb or anything part .sql any other extensions mentioned will captured.

if ($check_Manifestext -match ".txt")
{
  #Check if files mentioned in the Manifest file are present in the git if not fail a job with Missing file names
  $check_script = $file_seq | ?{ -not(Test-Path -Path $working_dir\$_ -PathType Leaf) } 
  if(-not([string]::IsNullOrEmpty($check_script)))
  {
    Write-Output "`n############################Files Missing in the Repo ###################################"
    $check_script | ?{ Write-Host "$_" }
    Write-Output "#########################################################################################`n"
    Write-Host "##vso[task.logissue type=error] $check_script These Lookups are not preasent in the repository"
    exit 1
  }
   
  #Loop through the Manifest file sequentially and execute the each file using sqlplus and capture the output in the "Output.txt"
  foreach($file in $file_seq)
  {
  $Lookup =[System.IO.Path]::GetFileNameWithoutExtension($file)
  Write-Host "Lookup Name $Lookup"
  Write-Host "File Name $working_dir/$file"
  #$filename = Get-ChildItem -Path $working_dir -Filter $file -Recurse | %{$_.FullName}
  # Write-Host "File Name $filename"
  $importArgumentList = '-u', "${user}:${pass}",
						    '-X', 'GET',
						    '-H', 'Accept:application/json',
						    "https://$url/$ext/$Lookup"
      Write-Host "The deployment is  $importArgumentList "
  
  	$import = & curl.exe $importArgumentList
     Write-Host "The deployment is  $import "
    $deloyJson = $import | Select-String -Pattern 'HTTP 404 Not Found' -CaseSensitive -SimpleMatch
    Write-Host "The deployment is  $deloyJson "
    if (-not ([string]::IsNullOrEmpty($deloyJson)))
		{
        $importArgumentCreate = '-u', "${user}:${pass}",
						    '-X', 'POST',
						    '-H', 'Accept:application/json',
						    '-F', "file=@$working_dir/$file", 
						    '-F', "type=application/octet-stream", 
						    "https://$url/$ext/archive"

      $import = & curl.exe @importArgumentCreate
    Write-Host "***********************************Command being executed while creating lookup $import**************************************"
        
		Write-Host "***********************************Lookup $Lookup is created**************************************"
			    }
              else
    {
      Write-Host "##vso[task.logissue type=error] $Lookup lookup already exists in $url"
    }
  }
}
else
{
    $Lookup =[System.IO.Path]::GetFileNameWithoutExtension($Manifest_file)
    $file_name = Get-ChildItem -Path $working_dir -Filter $Manifest_file -Recurse | %{$_.FullName}
      Write-Host "File Name $file_name"
    $importArgumentList = '-u', "${user}:${pass}",
						    '-X', 'GET',
						    '-H', 'Accept:application/json',
						    "https://$url/$ext/$Lookup"
      Write-Host "The deployment is  $importArgumentList "
  
  	$import = & curl.exe @importArgumentList
     Write-Host "Curl script to check lookup  $import "
    $deloyJson = $import | Select-String -Pattern 'HTTP 404 Not Found' -CaseSensitive -SimpleMatch
      Write-Host "Return Json:    $deloyJson "
    if (-not ([string]::IsNullOrEmpty($deloyJson)))
		{
      $importArgumentCreate = '-u', "${user}:${pass}",
						    '-X', 'POST',
						    '-H', 'Accept:application/json',
						    '-F', "file=@$file_name", 
						    '-F', "type=application/octet-stream", 
						    "https://$url/$ext/archive"
      $import = & curl.exe @importArgumentCreate
      Write-Host "***********************************Command being executed while creating lookup $import**************************************"
			Write-Host "***********************************Lookup ($Lookup) is created**************************************"
    }
    else
    {
      Write-Host "##vso[task.logissue type=error] $Lookup lookup already exists in $url"
    }
			Write-Host "***********************************Lookups Migration Completed**************************************"
}
 Catch {	
	  Write-Host "The Powershell failed with: $LastExitCode"
	  $ErrorMessage = $_.Exception.Message
    $Exception_line_num = $_.InvocationInfo.ScriptLineNumber
    Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
	  throw "$ErrorMessage"
	}

