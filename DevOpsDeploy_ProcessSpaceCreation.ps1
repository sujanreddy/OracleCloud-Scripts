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
	$spacename = "$env:SpaceName"
	$dbuser = "$env:DevOps_DB_User"
#	$dbpass = "$env:DevOps_DB_Pass"
	$DBName = "$env:DevOps_DB_Name"
	$url = "$env:instance_url"
 	Try {
$createspace =   '-u', "${user}:${pass}",
							'-X', 'POST',
							'-H', 'Content-Type: application/x-www-form-urlencoded',
							'-H', 'Accept: application/json',
							'-d', "spaceName=$spacename",
							"$url"
							
write-host "Response of Json $createspace "
try{
$import = & curl.exe $createspace 
write-host "Response of Json $import "
}
 Catch {
#$deloymentJson = $response | ConvertFrom-Json
$status = $_.Exception.Response.StatusCode
write-host "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
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
	 Catch {	
	  Write-Host "The Powershell failed with: $LastExitCode"
	  $ErrorMessage = $_.Exception.Message
	  $Exception_line_num = $_.InvocationInfo.ScriptLineNumber
      Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
	  throw "$ErrorMessage"
	}

	