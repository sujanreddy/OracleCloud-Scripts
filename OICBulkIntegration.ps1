<#
	####################################################################################################
	# File      : DevOpsDeploy_OICBulkIntegration.ps1                           
	# Author    : Sujan Gutha                                   
	# Created   : 08/13/2020                                           
	#                                                                  
	# Usage	: This powershell scripts used to Deploy the OICS iar file to cloud.
	#
	#                                                                  #
	# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
	#-------------------              ----------            -------------------------  
	# Sujan Gutha                    08/13/2020               Initial Created
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
     <Integration>
       <File>?</File>
     </Integration>
    </Migration>
'@
	Try {
	$filename = "$env:file_name"
	Write-Host "***File Name : $filename*******************"
	$filextension = [System.IO.Path]::GetExtension($filename)
	$branch =  "$env:branch"
	$dbuser = "$env:DevOps_DB_User"
#	$dbpass = "$env:DevOps_DB_Pass"
	$DBName = "$env:DevOps_DB_Name"
	Write-Host "***dbuser : $dbuser*******************"
	Write-Host "***dbpass : $dbpass*******************"
	Write-Host "***DBName : $DBName*******************"

		$var = "$env:file_name"
	
		$url = "$env:base_url"
	
		$ext = "$env:url_ext"
	
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
   $getfile.Migration.Integration.File = $filename
   $getfile.save($requestFile)
   $XMLfile = $requestFile
    Write-Host "***XML file : $XMLfile***************"
   [XML]$iarDetails = Get-Content $XMLfile
}	

foreach($iarDetail in $iarDetails.Migration.Integration)
{
Write-Host "iar Name :" $iarDetail.File
$var = $iarDetail.File
$length = $var.length
$result = $var.substring(0, $length -15)+"%7C"+$var.substring($length -14,10) 		
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
		$importArgumentexists = '-u', "${user}:${pass}",
						'-X', 'GET',
						 "https://$url/$ext/$result"
		Write-Host "***importArgumentexists : $importArgumentexists*******************"
		$importArgumentConf =   '-u', "${user}:${pass}",
							'-X', 'POST',
							'-H', 'Content-Type: Application/json',
							'-H', 'X-HTTP-Method-Override: PATCH',
							'-d', '{\"status\":\"CONFIGURED\"}',
							'-d', 'enableAsyncActivationMode=true',
							"https://$url/$ext/$result"
		$importArgumentCreate = '-u', "${user}:${pass}",
						    '-X', 'POST',
						    '-H', 'Accept:application/json',
						    '-F', "file=@$file_name", 
						    '-F', "type=application/octet-stream", 
						    "https://$url/$ext/archive"
		$importArgumentActivate = '-u', "${user}:${pass}",
							'-X', 'POST',	
							'-H', 'Content-Type: Application/json',
							'-H', 'X-HTTP-Method-Override: PATCH',
							'-d', '{\"status\":\"ACTIVATED\"}',
							"https://$url/$ext/$result"
		$importArgumentReplace = '-u', "${user}:${pass}",
						     '-X', 'PUT',
						     '-H', 'Accept:application/json',
						     '-F', "file=@$file_name", 
						     '-F', "type=application/octet-stream", 
						     "https://$url/$ext/archive"
		$importArgumentActErrors = '-u', "${user}:${pass}",
						'-X', 'GET',
						 "https://$url/$ext/$result/activationErrors"
						
		#$var = 'SOUTHE_CO_POET_PROJEC_SEGMEN_01.00.0000.iar'


		## Check if the Integration exists or not


		$import = & curl.exe $importArgumentexists 
		Write-Host "***********************************Checking if Integration($var) file exists**************************************"
		$deloymentJson = $import | ConvertFrom-Json
		Write-Host "Output of iar Exists REST API: $deloymentJson"
	 	if ( $deloymentJson.PSObject.Properties['code'] )
		{
			Write-Host "***********************************Integration($var) exists**************************************"
			$import = & curl.exe $importArgumentConf
			$deloymentJson = $import | ConvertFrom-Json
			Write-Host "***********************************Checking if we can deactivate the integration: $deloymentJson"
  
			$import = & curl.exe $importArgumentReplace
			Write-Host "***********************************Replacing Integration($var) : $import*******************"
			try
			{		
			$deloyment = & curl.exe $importArgumentActivate
			$deloymentJson = $deloyment | ConvertFrom-Json
			Write-Host "***********************************Activating Integration($var) : $deloymentJson*******************"
			}
		   catch
		   {
			Write-Host "The Powershell failed as Activation could not happen"
			$import = & curl.exe $importArgumentActErrors 
		   $deloymentJson = $import | ConvertFrom-Json
		   Write-Host "Output of iar Exists REST API: $deloymentJson"
		   Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$deloymentJson..occurred in the Powershell script line number : $Exception_line_num"
		   }
	      Write-Host "***********************************Migration Complete*******************"
		}
		else
		{

			$import = & curl.exe @importArgumentCreate
			Write-Host "***********************************Adding Integration($var) : $import*******************"
		$import = & curl.exe $importArgumentActivate
		Write-Host "***********************************Activating Integration($var) : $import*******************"
		}
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

	
