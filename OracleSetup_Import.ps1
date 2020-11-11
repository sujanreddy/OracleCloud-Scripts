<#
####################################################################################################
# File      : DevOpsDeploy_OracleSetup_Import.ps1                            
# Author    : Sujan Gutha                                   
# Created   : 05/13/2020                                           
#                                                                  
# Usage	: This powershell scripts used to Import the Setup Task in Oracle.
#
#                                                                  #
# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
#-------------------              ----------            -------------------------  
# Sujan Gutha                    05/13/2020               Initial Created
# Sujan Gutha                    08/24/2020               Added to get Task code Dynamically from the zip file for Setup Task Import
######################################################################################################
#>

Param(
	[string]$Importuser,
	[string]$Importpass
	)


Try {
# Below Envelope is Used to Submit the Oracle Setup Task Import Process
$exportTaskResult = [xml]@'
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/setup/migrator/setupDataExportImportService/types/">
   <soapenv:Header/>
   <soapenv:Body>
      <typ:getTaskCSVExportResultAsync>
         <typ:processId>?</typ:processId>
      </typ:getTaskCSVExportResultAsync>
   </soapenv:Body>
</soapenv:Envelope>
'@
$submitTask = [xml]@'
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/setup/migrator/setupDataExportImportService/types/" xmlns:set="http://xmlns.oracle.com/apps/setup/migrator/setupDataExportImportService/">
   <soapenv:Header/>
   <soapenv:Body>
      <typ:submitTaskCSVImportAsync>
         <typ:taskCSVImportParameter>
            <!--Optional:-->
            <set:TaskCode>?</set:TaskCode>
                        <!--Optional:-->
                         <set:FileContent>?</set:FileContent>
         </typ:taskCSVImportParameter>
      </typ:submitTaskCSVImportAsync>
   </soapenv:Body>
</soapenv:Envelope>
'@
# Below Envelope is Used to get the submitted  Oracle Setup Task Import Process from above Envelope
$getTask = [xml]@'
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/setup/migrator/setupDataExportImportService/types/">
   <soapenv:Header/>
   <soapenv:Body>
      <typ:getTaskCSVImportResultAsync>
         <typ:processId>?</typ:processId>
      </typ:getTaskCSVImportResultAsync>
   </soapenv:Body>
</soapenv:Envelope>
'@
#declare the parameters passed in from pipeline Variables
    $timeStamp    = (get-date).tostring('yyyy-MM-dd-HHmmss')
	$filename     = "$env:File"
	$taskcode     = "$env:Task"
	$time         = "$env:Time"
    $buildDef     = $env:Build_DefinitionName
	$requestFile  = "$env:System_DefaultWorkingDirectory\_$buildDef\"+"Submit.xml"
    $responseFile = "$env:System_DefaultWorkingDirectory\_$buildDef\"+"Response.log"
	$importurl    = "$env:Importurl/$env:wsdl"
	$ImportauthorizationHeaderValue = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${Importuser}:${Importpass}"))
    $ImportHeaders = @{
    Authorization = $ImportauthorizationHeaderValue
    
    }
    	
      Write-Host "##[debug] Printing Variables----------"
          Write-Host "***File Name : $filename *******************"
	      Write-Host "***Task Code : $taskcode *******************"
          Write-Host "***Time      : $time ***********************"
          Write-Host "***Requested Envolpe Details   : $requestFile ***********************"
          Write-Host "***Response Envelope Details   : $responseFile ***********************"
	      Write-Host "***Import WSDL Url  : $importurl  "
          Write-Host "***Build Definition Name  : $buildDef  "
    # Forcing the Transport layer security to be TLS1.2 as per indistry standards
    [Net.ServicePointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12
    # Checking for Taskcode is null or not
  <#  if (!$taskcode)
    {
          Write-Host "***File Name or Task Code cannot be null. Please enter Valid Parameters*******************"
          Write-Host "##vso[task.logissue type=error]File Name or Task Code cannot be null. Please enter Valid Parameters, $ErrorMessage"
    exit 1
    }#>

    if ($filename)
    {
   # Get the File Extension of the file
   Write-Host "##[debug] ***File name is Provided  : $filename  "
    $filextension = [System.IO.Path]::GetExtension($filename)
   Write-Host "***filextension variable is   : $filextension  "
   # If the File Extension is not a Zip FIle then exit the Powershell with Error 
    if ($filextension -notlike ".zip")
    {
           Write-Host "***File Name is not in correct format*******************"
           Write-Host "##vso[task.logissue type=error]File Name is not in correct format, $ErrorMessage"
    exit 1
    }
    # Search the Repo for the file, if there are multiple files in the Repo with the same name then exit the powershell with Error and logg the error
	$searchinfolder = "$env:System_DefaultWorkingDirectory\_$buildDef\"
	       Write-Host "***Search in Folder: $searchinfolder ***************"
	$file_name = Get-ChildItem -Path $searchinfolder -Filter $filename -Recurse | %{$_.FullName}
     Write-Host "***file_name: $file_name ***************"

	if ($file_name.Count -gt 1)
	{
	throw "There are more than 1 file in the Repo: $filename" 
	       Write-Host "##vso[task.logissue type=error]There are more than 1 file in the Repo:, $filename"
	}
	ElseIf  ($file_name.Count -lt 1) 
	{
	throw "There are no files in the Repo: $filename" 
	       Write-Host "##vso[task.logissue type=error]There are no files in the Repo:, $filename"
	}
    }
  # Added by Sujan Gutha to Get Task Code Dynamically from the Zip file
  if (!$taskcode)
  {
     Write-Host "***file_name: $file_name ***************"
    [void][Reflection.assembly]::LoadWithPartialName('System.IO.Compression')
    [void][Reflection.assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
    add-type -assemblyname 'System.IO.Compression'
    add-type -assemblyname 'System.IO.Compression.FileSystem'
    $arch = [System.IO.Compression.ZipFile]::OpenRead($file_name)
   
    $entryfilename = $arch.Entries | ?{$_.Name -like "ASM_SETUP_CSV_METADATA.xml"}
    
    if (!$entryfilename)
    {
        Write-Host "##vso[task.logissue type=error]Could not find the .xml file"
    }

    $buffer = New-Object System.Byte[]($entryfilename.Length)
   
   Try
   {
    $entryfilename.Open().Read($buffer, 0, $entryfilename.Length) | Out-Null
   }
   Catch {	
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=error]Error in getting the Buffer for Task Code, $ErrorMessage"
			exit 1
    }

    $reader = new-object System.IO.StreamReader($entryfilename.Open())
    $contents = $reader.ReadToEnd()
    $patterno = "<ObjectShortName>(.*?)</ObjectShortName>"
    $taskcode = [regex]::Match($contents,$patterno).Groups[1].Value
    Write-Host "Task Code from the file: $taskcode"
    $reader.Close();
  }
  # End to get Task Code Dynamically
      
   # Updating the values to the XML Envelope
    $submitTask.Envelope.Body.submitTaskCSVImportAsync.taskCSVImportParameter.TaskCode = $taskcode
           Write-Host "Transforming the data to Base64String"
    if ($filename)
    {
    $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file_name))
    $submitTask.Envelope.Body.submitTaskCSVImportAsync.taskCSVImportParameter.FileContent = $base64string
    }
    $submitTask.save($requestFile)
   # Adding the Header to Basic Authorization
 
    # Invoking the SOAP Request with the above parameters to Submit the task import process
    Try
    {
    Invoke-WebRequest -Uri $importurl -Headers $ImportHeaders -Method Post -ContentType "text/xml" -InFile $requestFile -OutFile $responseFile
    } Catch {	
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=error]Error in Invoking the Webrequest, $ErrorMessage"
			exit 1
    }
   Write-Host "Get-Content $responseFile"
   $filecontent = Get-Content $responseFile
   $pattern = "<ns1:ProcessId>(.*?)</ns1:ProcessId>"
   $result = [regex]::Match($filecontent,$pattern).Groups[1].Value
            Write-Host "##[debug] ************************The Below Output in Green is for Submitting Task Import Proces ***********************************************!"
            Write-Host "Process id : $result"
            Write-Host "##[section] $filecontent" 
 if (!$result)
  {
            Write-Host "***Process id is null*******************"
            Write-Host "##vso[task.logissue type=error]The Request is not submitted, $ErrorMessage"
   exit 1
  }
 Else
 {
     # Updating the values to the XML Envelope
   $getTask.Envelope.Body.getTaskCSVImportResultAsync.processId = $result
   $getTask.save($requestFile)
   $timeout = new-timespan -Minutes $time
   $sw = [diagnostics.stopwatch]::StartNew()
 while ($sw.elapsed -lt $timeout){
   # Invoking the SOAP Request with the above parameters to get the Task Status and Results
   Try
   {
   Invoke-WebRequest -Uri $importurl -Headers $ImportHeaders -Method Post -ContentType "text/xml" -InFile $requestFile -OutFile $responseFile
   }
   Catch {	
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=error]Error in Invoking the Webrequest, $ErrorMessage"
			exit 1
    }
   $filecontent = Get-Content $responseFile
   $pattern = "<ns1:StatusCode>(.*?)</ns1:StatusCode>"
   $result = [regex]::Match($filecontent,$pattern).Groups[1].Value
   Write-Host "Status: $result"
   # Looping the Cursor for every 10 sec to get the complete status
   
    if ($result -like "COMPLETED_ERRORS")
    {
          Write-Host "##[debug] ************************The Above Output in Green is for getting the Task Import Status Result ***********************************************!"
          Write-Host "##[debug] $filecontent"
          Write-Host "##vso[task.logissue type=error]The Request completed in Error. Please ignore the error if it is an HCM Fast Formulas or HCM Extracts Migration, $ErrorMessage"
        return
     }
    if (($result -like "COMPLETED") -or ($result -like "COMPLETED_WARNINGS") ) 
	    {
          Write-Host "##[debug] ************************The Above Output in Green is for getting the Task Import Status Result ***********************************************!"
          Write-Host "##[section] $filecontent"
        return
        }
     start-sleep -seconds 10
}
 }
   } Catch {	
	       Write-Host "The Powershell failed with: $LastExitCode"  
	$ErrorMessage = $_.Exception.Message
	$Exception_line_num = $_.InvocationInfo.ScriptLineNumber
           Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
	throw "$ErrorMessage"
}