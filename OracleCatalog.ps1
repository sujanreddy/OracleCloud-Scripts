<#
####################################################################################################
# File      : DevOpsDeploy-OracleCatalog.ps1                            
# Author    : Sujan Gutha                                   
# Created   : 12/19/2019                                           
#                                                                  
# Usage	: This powershell scripts used to Deploy the Oracle Catalog files for OTBI and OACS
#
#                                                                  #
# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
#-------------------              ----------            -------------------------  
# Sujan Gutha                    12/19/2019               Initial Created
# Sujan Gutha                    02/25/2020               Increased Timeout value
# Sujan Gutha                    06/10/2020               Increased Timeout value again as OACS pipeline is failing
# Sujan Gutha                    09/09/2020               Modified code to handle bulk Migrations of Catalog
######################################################################################################
#>

Param(
	[string]$user,
	[string]$pass,
	[string]$dbpass
)

#declare the parameters passed in from pipeline

$getcatalog = [xml]@'
<?xml version = '1.0' encoding = 'utf-8'?>
       <!--Deploy file used to migrate OTBI/OACS catalogs -->
   <Migration>
     <Report>
       <Catalog>?</Catalog>
       <Path>?</Path>
     </Report>
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
	

	$buildDef = $env:Build_DefinitionName

	$pathname = "$env:path_name"
	Write-Host "***Path Name : $pathname*******************"
	$searchinfolder = "$env:System_DefaultWorkingDirectory\_$buildDef\"
	Write-Host "***Build Def Variaable : $buildDef***************"
	#$searchinfolder = "$env:System_DefaultWorkingDirectory\_OTBI\"
$requestFile  = "$env:System_DefaultWorkingDirectory\_$buildDef\"+"Submit.xml"
 Write-Host "***Requested file : $requestFile***************"
if( $filextension -eq ".xml")
{
    Write-Host "***Entering XML Definition***************"
   $xmlpathname = $pathname.Replace("/","\")
   $XMLfile = "$env:System_DefaultWorkingDirectory\_Manifest\"+"$xmlpathname\"+"$filename"
   Write-Host "***XML File : $XMLfile***************"
   [XML]$RepDetails = Get-Content $XMLfile
}
else{
         # Updating the values to the XML Envelope
   $getcatalog.Migration.Report.Catalog = $filename
   $getcatalog.Migration.Report.Path = $pathname
   $getcatalog.save($requestFile)
   $XMLfile = $requestFile
   [XML]$RepDetails = Get-Content $XMLfile
}	
foreach($RepDetail in $RepDetails.Migration.Report)
{
 
Write-Host "Catalog Name :" $RepDetail.Catalog
Write-Host "Catalog Path :" $RepDetail.Path
Write-Host ''
$filename = $RepDetail.Catalog
$pathname = $RepDetail.Path
 
	$file_name = Get-ChildItem -Path $searchinfolder -Filter $filename -Recurse | %{$_.FullName}

	if ($file_name.Count -gt 1)
	{
	#	throw "There are more than 1 file in the Repo: $filename" 
			Write-Host "##vso[task.logissue type=error]There are more than 1 file in the Repo:, $filename"
			continue
	}
	ElseIf  ($file_name.Count -lt 1) 
	{
	#	throw "There are no files in the Repo: $filename" 
		Write-Host "##vso[task.logissue type=error]There are no files in the Repo:, $filename"
		continue 
	}

	if (!$pathname)
	{
		$folderpath = [IO.Path]::GetDirectoryName($file_name)
		Write-Host "***Folder Path : $folderpath*******************"
		$separator = "$env:seperator"
		Write-Host "***Seperator : $separator*******************"
		[string]$strfolderpath = $folderpath
		$search = '*'+$separator+'*'
		if ( $strfolderpath -like $search )
		{
			$firstpath,$secondpath = $folderpath -split $separator
		}
		else
		{
			Write-Host "##vso[task.logissue type=error]Error in Getting Report Structure, $folderpath"	
			Write-Host "***Catalog is not under Reports Folder Structure*******************"
			continue
		}
		
		$secondpath = '/shared/custom'+$secondpath.Replace("\","/")

		Write-Host "***Folder path where Report is migrated to: $secondpath*******************"

		$pathname = $secondpath
		Write-Host "***Folder structure is derived from the Repo*******************"
	}

	Write-Host "***File Name : $file_name*******************"
	if ($filextension = '.catalog')
	{
		$importurl = "$env:url/$env:wsdl"
		Write-Host "***importurl : $importurl*******************"
		Write-Host "***Stages the SOAPUI for Migration*******************"

		Try {

			[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
			$logonurl = New-WebServiceProxy -Uri $importurl
			Write-Host "***importurl : $logonurl *******************"
			if ($logontoken -eq $null)
			{
			$logontoken = $logonurl.logon(${user},${pass})
			}
			Write-Host "***Retreives the logontoken : $logontoken *******************"
            
		} Catch {	
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=error]Error in Getting Token, $ErrorMessage"
			exit 1
		}

		$proxy =  New-WebServiceProxy -Uri $importurl -Namespace "WebCatalogServiceSoap"
		

		Write-Host "***Port Type is changed to WebCatalogServic*******************"
		$proxy = New-Object WebCatalogServiceSoap.WebCatalogService		
		$proxy | gm

		Try {
				Write-Host "***Creates folder if it doesn't exists or else does nothing *******************"
			$proxy.Createfolder($pathname,"true","true",$logontoken)
			} Catch 
			{	
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=error]Error in creation Folder, $ErrorMessage"
			throw "$ErrorMessage"
			
		}

		Try {
			Write-Host "***Migrating the catalog file to:  $env:url*******************"
			#Increase Timeout value to mitigate timeout error from the api
			$proxy.Timeout = 20000000
			$proxy.pasteItem2((Get-Content $file_name -Encoding byte),$pathname,1,1,$logontoken)
			}
		Catch {	
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=warning]Error in Migrating the catalog, $ErrorMessage"
			throw "$ErrorMessage"
			
		}
	}
} 
Try {
			Write-Host "***Logingoff the token *******************"
			$logofftoken = $logonurl.logoff($logontoken)
			        
	} Catch {	
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=error]Error in Getting Token, $ErrorMessage"
			exit 1
		    }
}Catch {	
	Write-Host "The Powershell failed with: $LastExitCode"
	$ErrorMessage = $_.Exception.Message
	$Exception_line_num = $_.InvocationInfo.ScriptLineNumber
    Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
	throw "$ErrorMessage"
}	
