<#
####################################################################################################
# File      : DevOpsBuild_OICCloneImport.ps1                      
# Author    : Sujan Gutha	                                    
# Created   : 06/10/2020                                          
#                                                                  
# Usage	:  Script to Import the OIC Metadata information.
#          - This imports from the object storage to Destination Instance
#                                                                  #
# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
#-------------------              ----------            -------------------------  
# Sujan Gutha            06/10/2020               Initial Created
######################################################################################################
#>

Param(
	[string]$SRC_OIC_PASSWORD,
	[string]$STORAGE_PASSWORD
)

Try {

    $oic_host   = "$env:SRC_OIC_TARGET_URL"
    $oic_user   = "$env:SRC_OIC_USER"
    $Mode       = "$env:Mode"
    $store_url  = "$env:STORAGE_URL"
    $store_user = "$env:STORAGE_USER"
    $File_Name  = "$env:File_Name"
  

    $delay    = 60
    $counter  = 0
    $tryTimes = 10
    Write-Host "SRC_OIC_TARGET_URL :  $oic_host"
    Write-Host "SRC_OIC_USER       :  $oic_user"
    Write-Host "SRC_OIC_PASSWORD   :  $oic_pass"
    Write-Host "STORAGE_URL        :  $store_url"
    Write-Host "STORAGE_USER       :  $store_user"
    Write-Host "STORAGE_PASSWORD   :  $store_pass"
    Write-Host "File_Name          :  $File_Name"

    $postBody = @{"archiveFile"="$File_Name";"importActivateMode"="$Mode";"storageInfo"= @{"storageUrl"="$store_url";"storageUser"="$store_user";"storagePassword"="${STORAGE_PASSWORD}"} }
    Write-Host "Post Body :  $postBody"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    ## Authorization Header
    $AuthorizationHeaderValue = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${oic_user}:${SRC_OIC_PASSWORD}"))
    $Headers = @{ Authorization = $AuthorizationHeaderValue }

    ## Export REST Api Post Method
    $resJsonObj = Invoke-RestMethod -Uri $oic_host -Headers $Headers -Method Post -ContentType "application/json" -Body ($postBody|ConvertTo-Json)
    $jobId = $resJsonObj.jobId
    $location = $resJsonObj.location
    $importStatus = $resJsonObj.status
     Write-Host "Job Id       :  $jobId"
     Write-Host "location     :  $location"
     Write-Host "importStatus :  $importStatus"

    Write-Host "Status :$importStatus and Job Id: $jobId"

    Do {
        ## Sleep and increase counter
        Write-Host "Sleeping for $delay seconds..."
        Start-Sleep -Seconds $delay
        $counter++

        Write-Host "Execute the Status Check..."
        $resJsonObj = Invoke-RestMethod -Uri "$oic_host/$jobId" -Headers $Headers -Method Get
        $importStatus = $resJsonObj.overallStatus
        Write-Host "Import Status : $importStatus"

    }while ( ($importStatus -ne "COMPLETED") -And ($counter -le $tryTimes) )

    if( $importStatus -eq "COMPLETED" ) {
        $archiveName = $resJsonObj.archiveName
        Write-Host "Archive Name :$archiveName"
    }else {
        Write-Host "##vso[task.logissue type=warning] Job :$jobId is not complete yet. Last Status: $importStatus"
    }

}Catch {

	$ErrorMessage = $_.Exception.Message
	$Exception_line_num = $_.InvocationInfo.ScriptLineNumber
    Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
	throw "$ErrorMessage"
}
