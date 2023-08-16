<#
	####################################################################################################
	# File      : DevOpsDeploy_ProcessCloud.ps1                           
	# Author    : Sujan Gutha                                   
	# Created   : 02/10/2022                                           
	#                                                                  
	# Usage	: This powershell scripts used to Deploy the OICS iar file to cloud.
	#
	#                                                                  #
	# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
	#-------------------              ----------            -------------------------  
	# Sujan Gutha                    02/10/2022               Initial Created
	######################################################################################################
	#>

	Param(
	   [string]$user,
	   [string]$pass,
	   [string]$dbpass
		)
	#declare the parameters passed in from pipeline
  $getfile = [xml]@'
<?xml version = '1.0' encoding = 'utf-8'?>
       <!--Deploy file used to migrate iar files -->
   <Migration>
     <Process>
       <File>?</File>
	   <Version>?</Version>
     </Process>
</Migration>
'@
	Try {
	$filename = "$env:file_name"
	$Version = "$env:Version"
	Write-Host "***File Name : $filename*******************"
	$filextension = [System.IO.Path]::GetExtension($filename)
	[System.IO.Path]::GetFileNameWithoutExtension('D:\LogTest\Newline-FileTest.txt')
	$branch =  "$env:branch"
	$dbuser = "$env:DevOps_DB_User"
#	$dbpass = "$env:DevOps_DB_Pass"
	$DBName = "$env:DevOps_DB_Name"
	$spaceid =  "$env:spaceid"
		$var = "$env:file_name"
		$url = "$env:base_url"
		$ext = "$env:url_ext"
		$urlspace = "$env:base_url"

		$TracingEnabled = "$env:TracingEnabled"
		$payloadTracingEnabledFlag = "$env:payloadTracingEnabledFlag"
	
		#$length = $var.length
	
	#	$result = $var.substring(0, $length -15)+"%7C"+$var.substring($length -14,10)
		Write-Host "Test: $url/$ext/$result"
		$ReleaseDef = $env:Release_PrimaryArtifactSourceAlias
		$pathname = "$env:path_name"
	    Write-Host "***Path Name : $pathname*******************"
		#$searchinfolder = "$env:System_DefaultWorkingDirectory\_OICS\"
		Write-Host "***Build Def Variaable : $ReleaseDef***************"
		$searchinfolder = "$env:System_DefaultWorkingDirectory\$ReleaseDef\"
		Write-Host "***Search Folder : $searchinfolder***************"
    $requestFile  = "$env:System_DefaultWorkingDirectory\$ReleaseDef\"+"Submit.xml"
   Write-Host "***Requested file : $requestFile***************"
	if( $filextension -eq ".xml")
{
    Write-Host "***Entering XML Definition***************"
   $xmlpathname = $pathname.Replace("/","\")
   $XMLfile = "$env:System_DefaultWorkingDirectory\_Manifest\"+"$xmlpathname\"+"$filename"
   Write-Host "***XML File : $XMLfile***************"
   [XML]$iarDetails = Get-Content $XMLfile
}
else{
         # Updating the values to the XML Envelope
   Write-Host "***Entering XML Definition***************"
   $getfile.Migration.Process.File = $filename
   $getfile.Migration.Process.Version = $Version
   $getfile.save($requestFile)
   $XMLfile = $requestFile
    Write-Host "***XML file : $XMLfile***************"
   [XML]$iarDetails = Get-Content $XMLfile
}
$pair = "$($user):$($pass)"
## Encode the String
$bytes=[System.Text.Encoding]::ASCII.GetBytes($pair)
$base64=[System.Convert]::ToBase64String($bytes)
$basicAuthVal = "Basic $base64"	
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", $basicAuthVal)
$URL = "$url/$ext"
$CODEPAGE = "iso-8859-1"
$enc = [System.Text.Encoding]::GetEncoding($CODEPAGE)

foreach($process in $iarDetails.Migration.Process)
{
Write-Host "iar Name :" $process.File
$var = $process.File
$version = $process.Version
$filewithoutext = [System.IO.Path]::GetFileNameWithoutExtension("$var")
$file_name = Get-ChildItem -Path $searchinfolder -Filter $var -Recurse | %{$_.FullName}
		
		if ($file_name.Count -gt 1)
		{
			Write-Host "##vso[task.logissue type=error]There are more than 1 file in the Repo:, $var"
			#throw "There are more than 1 file in the Repo: $var" 
			continue
		}
		ElseIf  ($file_name.Count -lt 1) 
		{
			Write-Host "##vso[task.logissue type=error]There are no files in the Repo:, $var"
			#throw "There are no files in the Repo: $var" 
			continue
		}
		Write-Host "***File Name : $file_name*******************"
	#$var = 'SOUTHE_CO_POET_PROJEC_SEGMEN_01.00.0000.iar'
	$TheFile = [System.IO.File]::ReadAllBytes($file_name)
	$TheFileContent = $enc.GetString($TheFile)
	$boundary = [System.Guid]::NewGuid().ToString(); 
	$LF = "`r`n";
	
	$bodyLines = ( 
"--$boundary",
    "Content-Disposition: form-data; name=`"restDeployConfig`"$LF",
    "{`"revisionId`": `"$version`", `"overwrite`": true, `"forceDefault`": true, `"addMeToAllRoles`": true}",
    "--$boundary",
    "Content-Disposition: form-data; name=`"exp`"; filename=`"$var`"",
    "Content-Type: application/json$LF",
    $TheFileContent,
    "--$boundary--$LF" 
) -join $LF

$bodyproject = ( 
	 "--$boundary",
    "Content-Disposition: form-data; name=`"projectName`"$LF",
    "$filewithoutext",
    "--$boundary",
    "Content-Disposition: form-data; name=`"description`"$LF",
    "$filewithoutext",
      "--$boundary",
	  	 "Content-Disposition: form-data; name=`"exp`"; filename=`"$var`"",
    "Content-Type: application/json$LF",
    $TheFileContent,
    "--$boundary--$LF" 
) -join $LF

$URLPROJ = "$urlspace/ic/api/process/v1/spaces/$spaceid/projects"
Write-Host "***Body Project : $URLPROJ*******************"
try{
$response = Invoke-RestMethod -Uri $URLPROJ -Method Post -Headers $headers -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyproject
write-host "##[section] Creating a New Application $filewithoutext"
}
 Catch {
#$deloymentJson = $response | ConvertFrom-Json
$status = $_.Exception.Response.StatusCode
write-host "##[section] Application already exists so we are not creating any new application"
 }
if ( $status -eq "409" )
{
write-host "##[debug] Application already exists so incrementing with: $version"
$response = Invoke-RestMethod -Uri $URL -Method Post -Headers $headers -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines
}
 write-host "Invoke Rest Method Response: $response"
        try
			{
		Write-Output "<<<<<<<<<Before Updating RELEASE INFO DB Table>>>>>>>>>>>>>>>>>>>>"
		 . "$env:DevOps_DB_Operation_Script\devops_db_operations.ps1"
		 Write-Output "<<<<<<<<<Updating RELEASE INFO DB Table>>>>>>>>>>>>>>>>>>>>"
         sqlreleaseinsert "$branch" "$env:Release_EnvironmentName" -Manifest "$var" -Attribute1 "Manifest_file=$var"
			}
		  catch
		   {
			Write-Host "The Powershell failed The Powershell failed in inserting the release information into the table"
			Write-Host  "##vso[task.logissue type=error]Unhandled Exception,..occurred in the Powershell script line number : $Exception_line_num"
		   }	
	}
	} Catch {	
	  Write-Host "The Powershell failed with: $LastExitCode"
	  $ErrorMessage = $_.Exception.Message
	  $Exception_line_num = $_.InvocationInfo.ScriptLineNumber
      Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
	  throw "$ErrorMessage"
	}

	