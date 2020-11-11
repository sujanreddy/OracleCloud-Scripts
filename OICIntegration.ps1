	<#
	####################################################################################################
	# File      : DevOpsDeploy-OICS.ps1                            
	# Author    : Sujan Gutha                                   
	# Created   : 12/18/2019                                           
	#                                                                  
	# Usage	: This powershell scripts used to Deploy the OICS iar file to cloud.
	#
	#                                                                  #
	# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
	#-------------------              ----------            -------------------------  
	# Sujan Gutha                    12/18/2019               Initial Created
	# Sujan Gutha                    02/19/2020               Added Try Catch for Activating integration
	# Sujan Gutha                    08/04/2020               Removed the Hardcoded value and retrive the Dynamic Build Definition
	######################################################################################################
	#>

	Param(
	   [string]$user,
	   [string]$pass
		)
	#declare the parameters passed in from pipeline

	Try {

		$var = "$env:file_name"
	
		$url = "$env:base_url"
	
		$ext = "$env:url_ext"
	
		$length = $var.length
	
		$result = $var.substring(0, $length -15)+"%7C"+$var.substring($length -14,10)
		Write-Host "Test: $url/$ext/$result"
		$ReleaseDef = $env:Release_PrimaryArtifactSourceAlias
		#$searchinfolder = "$env:System_DefaultWorkingDirectory\_OICS\"
		Write-Host "***Build Def Variaable : $ReleaseDef***************"
		$searchinfolder = "$env:System_DefaultWorkingDirectory\$ReleaseDef\"
		Write-Host "***Search Folder : $searchinfolder***************"
		
		$file_name = Get-ChildItem -Path $searchinfolder -Filter $var -Recurse | %{$_.FullName}
		
		if ($file_name.Count -gt 1)
		{
			Write-Host "##vso[task.logissue type=error]There are more than 1 file in the Repo:, $var"
			throw "There are more than 1 file in the Repo: $var" 
		}
		ElseIf  ($file_name.Count -lt 1) 
		{
			Write-Host "##vso[task.logissue type=error]There are no files in the Repo:, $var"
			throw "There are no files in the Repo: $var" 
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
	} Catch {	
	  Write-Host "The Powershell failed with: $LastExitCode"
	  $ErrorMessage = $_.Exception.Message
	  $Exception_line_num = $_.InvocationInfo.ScriptLineNumber
      Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
	  throw "$ErrorMessage"
	}

	