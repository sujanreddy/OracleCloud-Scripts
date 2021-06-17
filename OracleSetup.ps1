<#
####################################################################################################
# File      : DevOpsDeploy-OracleSetup.ps1                            
# Author    : Sujan Gutha                                   
# Created   : 04/08/2020                                           
#                                                                  
# Usage	: This powershell scripts used to Deploy the Setup Task in Oracle.
#
#                                                                  #
# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
#-------------------              ----------            -------------------------  
# Sujan Gutha                    04/08/2020               Initial Created
#
######################################################################################################
#>

Param(
	[string]$Importuser,
	[string]$Importpass,
	[string]$Exportuser,
	[string]$Exportpass,
    [string]$ServiceAccount,
    [string]$ServiceAccountPass
)


Try {
# Below Envelope is Used to Submit the Oracle Setup Task Import Process
$exportTask = [xml]@'
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/setup/migrator/setupDataExportImportService/types/" xmlns:set="http://xmlns.oracle.com/apps/setup/migrator/setupDataExportImportService/">
   <soapenv:Header/>
   <soapenv:Body>
      <typ:submitTaskCSVExportAsync>
         <typ:taskCSVExportParameter>
            <!--Optional:-->
            <set:TaskCode>?</set:TaskCode>
         </typ:taskCSVExportParameter>
         <!--Zero or more repetitions:-->
         <typ:taskCSVExportCriteria>
            <!--Optional:-->
            <set:BusinessObjectCode>?</set:BusinessObjectCode>
            <!--Optional:-->
            <set:AttributeSet>?</set:AttributeSet>
            <!--Optional:-->
            <set:AttributeName>?</set:AttributeName>
            <!--Optional:-->
            <set:AttributeValue>?</set:AttributeValue>
         </typ:taskCSVExportCriteria>
      </typ:submitTaskCSVExportAsync>
   </soapenv:Body>
</soapenv:Envelope>
'@
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
    $responseFile = "$env:System_DefaultWorkingDirectory\_$buildDef\"+"Response.xml"
	$importurl    = "$env:Importurl/$env:wsdl"
	$ImportauthorizationHeaderValue = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${Importuser}:${Importpass}"))
    $ImportHeaders = @{
    Authorization = $ImportauthorizationHeaderValue
    }
	$Exporturl    = "$env:Exporturl/$env:wsdl"
	$ExportauthorizationHeaderValue = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${Exportuser}:${Exportpass}"))
    $ExportHeaders = @{
    Authorization = $ExportauthorizationHeaderValue
    }
	$password     = [uri]::EscapeDataString(${ServiceAccountPass})
      Write-Host "##[debug] Printing Variables----------"
          Write-Host "***File Name : $filename *******************"
	      Write-Host "***Task Code : $taskcode *******************"
          Write-Host "***Time      : $time ***********************"
          Write-Host "***Requested Envolpe Details   : $requestFile ***********************"
          Write-Host "***Response Envelope Details   : $responseFile ***********************"
	      Write-Host "***Import WSDL Url  : $importurl  "
          Write-Host "***Export WSDL Url  : $Exporturl  "
          Write-Host "***Build Definition Name  : $buildDef  "
    # Forcing the Transport layer security to be TLS1.2 as per indistry standards
    [Net.ServicePointManager]::SecurityProtocol =[Net.SecurityProtocolType]::Tls12
    # Checking for Taskcode is null or not
    if (!$taskcode)
    {
          Write-Host "***File Name or Task Code cannot be null. Please enter Valid Parameters*******************"
          Write-Host "##vso[task.logissue type=error]File Name or Task Code cannot be null. Please enter Valid Parameters, $ErrorMessage"
    exit 1
    }

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
    Else
    {
        Write-Host "***Getting ready to export the Task Details from Environment*******************"
        #  Updating the values to the XML Envelope

     $exportTask.Envelope.Body.submitTaskCSVExportAsync.taskCSVExportParameter.TaskCode = $taskcode
     $exportTask.save($requestFile)

     Try
    {
    Invoke-WebRequest -Uri $Exporturl -Headers $ExportHeaders -Method Post -ContentType "text/xml" -InFile $requestFile -OutFile $responseFile
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
            Write-Host "##[debug] ************************The Below Output in Green is for Submitting Task Export Proces ***********************************************!"
            Write-Host "Pricess Id:  $result" 
      if (!$result)
  {
            Write-Host "***Process id is null*******************"
            Write-Host "##vso[task.logissue type=error]The Request is not submitted, $ErrorMessage"
   exit 1
  }
 Else
 {
      Write-Host "***Checking the status of the Process id *******************"
     # Updating the values to the XML Envelope
   $exportTaskResult.Envelope.Body.getTaskCSVExportResultAsync.processId = $result
   $exportTaskResult.save($requestFile)
   $timeout = new-timespan -Minutes $time
   $sw = [diagnostics.stopwatch]::StartNew()
 while ($sw.elapsed -lt $timeout){
   # Invoking the SOAP Request with the above parameters to get the Task Status and Results
   Try
   {
   Invoke-WebRequest -Uri $Exporturl -Headers $ExportHeaders -Method Post -ContentType "text/xml" -InFile $requestFile -OutFile $responseFile
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
          Write-Host "##[debug] ************************The Above Output in Green is for getting the Task Export Status Result as Errors***********************************************!"
          Write-Host "##[section] $filecontent"
          Write-Host "##vso[task.logissue type=error]The Request completed in Error, $ErrorMessage"
    exit 1   
    }
    if (($result -like "COMPLETED") -or ($result -like "COMPLETED_WARNINGS") ) 
	    {
          Write-Host "##[debug] ************************The Above Output in Green is for getting the Task Export Status Result ***********************************************!"
     $filecontent = Get-Content $responseFile
     $file_name = "<ns1:FileName>(.*?)</ns1:FileName>"
     $FileNameExt = [regex]::Match($filecontent,$file_name).Groups[1].Value
     $FileNameWoExt = [io.path]::GetFileNameWithoutExtension($FileNameExt)
  Try
   {
   Invoke-WebRequest -Uri $Exporturl -Headers $ExportHeaders -Method Post -ContentType "text/xml" -InFile $requestFile -OutFile "$env:System_DefaultWorkingDirectory\_$buildDef\$FileNameWoExt.tar.gz"
   }
     Catch {	
			Write-Host "The Powershell failed with: $LastExitCode"
			$ErrorMessage = $_.Exception.Message
			Write-Host "##vso[task.logissue type=error]Error in Invoking the Webrequest, $ErrorMessage"
			exit 1
    }
    $timeout = new-timespan -Minutes 0 
        }
    start-sleep -seconds 10
}
 }
     
    }    
   # Updating the values to the XML Envelope
    $submitTask.Envelope.Body.submitTaskCSVImportAsync.taskCSVImportParameter.TaskCode = $taskcode
           Write-Host "Transforming the data to Base64String"
    if ($filename)
    {
    $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file_name))
    $submitTask.Envelope.Body.submitTaskCSVImportAsync.taskCSVImportParameter.FileContent = $base64string
    }
    Else
    {
         Write-Host "Unzip and Zipping the Extract"
         Write-Host "Destination Path:  $env:System_DefaultWorkingDirectory\_$buildDef\$taskcode\$FileNameExt"
         7z x -o"$env:System_DefaultWorkingDirectory\_$buildDef\$taskcode" "$env:System_DefaultWorkingDirectory\_$buildDef\$FileNameWoExt.tar.gz" -r ;
    Compress-Archive -Path "$env:System_DefaultWorkingDirectory\_$buildDef\$taskcode\*" -DestinationPath "$env:System_DefaultWorkingDirectory\_$buildDef\$taskcode\$FileNameExt"

    Write-Host "Destination Zip file which was extracted $FileNameExt"
    
    $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:System_DefaultWorkingDirectory\_$buildDef\$taskcode\$FileNameExt"))    
    
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
          Write-Host "##[section] $filecontent"
          Write-Host "##vso[task.logissue type=error]The Request completed in Error, $ErrorMessage"
    cd "$env:System_DefaultWorkingDirectory"
 
    & git clone https://"${ServiceAccount}:$password"@host_name/DevOps/_git/OracleLogs
    cd OracleLogs
    
    $path = "$pwd\Oracle Setup Logs\$taskcode"
  If(!(test-path $path))
    {
      New-Item -ItemType Directory -Force -Path $path
    }
    Copy-Item $responseFile -Destination ".\Oracle Setup Logs\$taskcode\$taskcode.log"
 if (!$filename)
    {
    Copy-Item "$env:System_DefaultWorkingDirectory\_$buildDef\$taskcode\$FileNameExt" -Destination ".\Oracle Setup Logs\$taskcode\$taskcode.zip"
    }
& git config --global --list
    & git add .
    & git status
    & git commit -a -m "$taskcode$timeStamp has been created and pushed"
    & git  push https://${ServiceAccount}:$password@host_name/DevOps/_git/OracleLogs --all
	exit 1   
    }
    if (($result -like "COMPLETED") -or ($result -like "COMPLETED_WARNINGS") ) 
	    {
          Write-Host "##[debug] ************************The Above Output in Green is for getting the Task Import Status Result ***********************************************!"
          Write-Host "##[section] $filecontent"
    cd "$env:System_DefaultWorkingDirectory"
    & git clone https://"${ServiceAccount}:$password"@host_name/DevOps/_git/OracleLogs
    cd OracleLogs
   # git checkout master
   
     $path = "$pwd\Oracle Setup Logs\$taskcode"
  If(!(test-path $path))
    {
      New-Item -ItemType Directory -Force -Path $path
    }
     Copy-Item $responseFile -Destination ".\Oracle Setup Logs\$taskcode\$taskcode.log"
    if (!$filename)
    {
    Copy-Item "$env:System_DefaultWorkingDirectory\_$buildDef\$taskcode\$FileNameExt" -Destination ".\Oracle Setup Logs\$taskcode\$taskcode.zip"
    }
    & git config --global --list
    & git add .
    & git status
    & git commit -a -m "$taskcode$timeStamp has been created and pushed"
    & git  push https://${ServiceAccount}:$password@host_name/DevOps/_git/OracleLogs --all
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
