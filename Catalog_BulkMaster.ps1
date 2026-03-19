<#
####################################################################################################
# File      : DevOpsDeploy-Catalog_BulkMigration.ps1                            
# Author    : Sujan Gutha                                   
# Created   : 12/19/2019                                           
#                                                                  
# Usage	: This powershell scripts used to Deploy Oracle Catalog files for OTBI and OACS
#         Uses AUTO-DISCOVERY pattern matching setup script for simplicity
#
# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
#-------------------              ----------            -------------------------  
# Sujan Gutha                    12/19/2019               Initial Created
# Sujan Gutha                    02/25/2020               Increased Timeout value
# Sujan Gutha                    06/10/2020               Increased Timeout value again as OACS pipeline is failing
# Sujan Gutha                    09/09/2020               Modified code to handle bulk Migrations of Catalog
# Sujan Gutha                    01/23/2021               Modified code to handle Replace All variables as per SOCO-149964
# Solumtochukwu Orji             11/24/2025               Refactored to use AUTO-DISCOVERY pattern like setup script
# Solumtochukwu Orji             11/06/2025               Added logging and error handling improvements
######################################################################################################
#>

Param(
	[string]$user,
	[string]$pass,
	[string]$dbpass
)

Try {
	#declare the parameters passed in from pipeline Variables
	$branch = "$env:branch"
	$buildDef = $env:Build_DefinitionName
	$dbuser = "$env:DevOps_DB_User"
	$DBName = "$env:DevOps_DB_Name"
	$deployFolder = "$env:System_DefaultWorkingDirectory\_$buildDef\CatalogArtifact"
	$requestFile = "$env:System_DefaultWorkingDirectory\_$buildDef" + "Submit.xml"
	$flagACL = "$env:flagACL"
	$flagOverwrite = "$env:flagOverwrite"

	Write-Host "##[debug] Printing Variables----------"
	Write-Host "***Build Definition Name  : $buildDef  "
	Write-Host "***Branch : $branch  "
	Write-Host "***DBName : $DBName*******************"
	Write-Host "***Deploy Folder : $deployFolder*******************"
	Write-Host "***flagACL : $flagACL *******************"
	Write-Host "***flagOverwrite : $flagOverwrite *******************"

	# Forcing the Transport layer security to be TLS1.2 as per industry standards
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	# ===== AUTO-DISCOVERY: Scan for catalog files in deployFolder =====
	Write-Host "######## AUTO-DISCOVERY: Scanning for catalog files ########"
	Write-Host "##[debug] Searching in: $deployFolder"

	$catalogFiles = @()
	if (Test-Path $deployFolder) {
		Write-Host "##[debug] Deploy folder exists; scanning for *.catalog files recursively..."
		$allCatalogs = @(Get-ChildItem -Path $deployFolder -Filter *.catalog -File -Recurse -Force)
		Write-Host "##[debug] Total catalog files found: $($allCatalogs.Count)"
		$allCatalogs | ForEach-Object { Write-Host "##[debug]   Found: $($_.FullName)" }
		
		$catalogFiles = $allCatalogs | ForEach-Object { $_.FullName }
	}
	else {
		Write-Host "##vso[task.logissue type=error]Deploy folder does not exist: $deployFolder"
		exit 1
	}

	if (-not $catalogFiles) {
		Write-Host "##vso[task.logissue type=warning]No catalog files found in $deployFolder; nothing to process"
		Write-Host "##[debug] Expected catalogs at: $deployFolder and subdirectories"
		exit 0
	}

	Write-Host "Discovered catalog files ($($catalogFiles.Count) file(s)):"
	$catalogFiles | ForEach-Object { Write-Host "  $_" }
	# ========================================================================================================

	foreach ($catalogItem in $catalogFiles) {
		$filename = Split-Path -Path $catalogItem -Leaf
		$file_name = $catalogItem
		
		Write-Host "`n##[section] Processing catalog: $filename"
		Write-Host "***File Name : $file_name*******************"

		# Get file extension
		$filextension = [System.IO.Path]::GetExtension($filename)
		Write-Host "##[debug] File extension: $filextension"

		if ($filextension -notlike ".catalog") {
			Write-Host "##vso[task.logissue type=error]File is not .catalog format: $filename"
			continue
		}

		# Derive pathname from folder structure if not explicitly set
		$pathname = "$env:path_name"
		if (!$pathname) {
			$folderpath = [IO.Path]::GetDirectoryName($file_name)
			$relativeFolder = $folderpath -replace [regex]::Escape($deployFolder), ""
			
			# Strip the first folder level (separator folder like BICustom, Custom, etc.)
			$relativeParts = $relativeFolder.Trim('\', '/') -split '[/\\]'
			if ($relativeParts.Count -gt 1) {
				$relativeFolder = '/' + ($relativeParts[1..($relativeParts.Count - 1)] -join '/')
			}
			else {
				$relativeFolder = ''
			}
			
			$pathname = "/shared/Custom$relativeFolder"
			Write-Host "##[debug] Derived pathname from folder structure: $pathname"
		}
		else {
			Write-Host "##[debug] Using provided pathname: $pathname"
		}

		Write-Host "***Catalog Path : $pathname*******************"

		# Normalize pathname
		$pathname = $pathname.replace('Shared', 'shared').replace('custom', 'Custom')

		Try {
			$importurl = "$env:url/$env:wsdl"
			Write-Host "***Import URL : $importurl*******************"

			# Authenticate and get token
			[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
			$logonurl = New-WebServiceProxy -Uri $importurl
			$logontoken = $logonurl.logon(${user}, ${pass})
			Write-Host "##[debug] Authentication token obtained"

			# Create catalog service proxy
			$proxy = New-WebServiceProxy -Uri $importurl -Namespace "WebCatalogServiceSoap"
			$proxy = New-Object WebCatalogServiceSoap.WebCatalogService
			$proxy.Timeout = 200000000

			# Create folder structure if needed
			Try {
				Write-Host "##[debug] Creating folder structure: $pathname"
				$proxy.Createfolder($pathname, "true", "true", $logontoken)
				Write-Host "##[debug] Folder created or already exists"
			}
			Catch {
				Write-Host "##vso[task.logissue type=warning]Error creating folder: $($_.Exception.Message)"
			}

			# Upload catalog file
			Try {
				Write-Host "##[debug] Uploading catalog file: $filename to $pathname"
				$proxy.pasteItem2((Get-Content $file_name -Encoding Byte), $pathname, $flagACL, $flagOverwrite, $logontoken)
				Write-Host "##[section] Catalog uploaded successfully: $filename"
			}
			Catch {
				Write-Host "##vso[task.logissue type=error]Error uploading catalog: $($_.Exception.Message)"
				throw $_
			}

			# Logoff
			Try {
				$logonurl.logoff($logontoken)
				Write-Host "##[debug] Token invalidated"
			}
			Catch {
				Write-Host "##vso[task.logissue type=warning]Error during logoff: $($_.Exception.Message)"
			}

			# Update database
			Try {
				Write-Host "##[debug] Updating release info in database..."
				. "$env:DevOps_DB_Operation_Script\devops_db_operations.ps1"
				sqlreleaseinsert "$branch" "$env:Release_EnvironmentName" -Manifest "$filename" -Attribute1 "catalog_file=$filename | catalog_path=$pathname"
				Write-Host "##[debug] Database updated successfully"
			}
			Catch {
				Write-Host "##vso[task.logissue type=warning]Error updating database: $($_.Exception.Message)"
			}

		}
		Catch {
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=error]Error processing catalog $filename : $ErrorMessage"
			throw "$ErrorMessage"
		}
	}

	Write-Host "`n##[section] Catalog deployment completed successfully"

}
Catch {
	Write-Host "The Powershell failed with: $LastExitCode"
	$ErrorMessage = $_.Exception.Message
	$Exception_line_num = $_.InvocationInfo.ScriptLineNumber
	Write-Host "##vso[task.logissue type=error]Unhandled Exception: $ErrorMessage (line $Exception_line_num)"
	throw "$ErrorMessage"
}	
