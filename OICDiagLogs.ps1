<#
####################################################################################################
# File      : DevOpsDeploy_DiagLogs.ps1                          
# Author    : Satheesh Viswanathan                                    
# Created   : 06/10/2020                                           
#                                                                  
# Usage	: This powershell script will use the OIC REST API to fetch the diagnostic log
          - And copy to the specified folder to be processed by splunk
#                                                                  
# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
#-------------------              ----------            -------------------------  
# Satheesh Viswanathan              06/10/2020              Initial Version
#
######################################################################################################
#>

param(
  [string]$oic_user,
  [string]$oic_pass
)

try {

    $url = "$env:oics_url"
    $log = "$env:oics_logtype"

    ## Create OICS_LOGS folder in E:/ if not already present
    $logFolder = "E:/OICS_LOGS"
    if( !(Test-Path -path $logFolder) ) {

        Write-Host "Creating OICS_LOGS folder...."
        New-Item -ItemType Directory -Path $logFolder -Force
    }
    <#
    else {
        Remove-Item "$logFolder\*.*"
    }
    #>

    ## Create Authorization Headers
    $ImportauthorizationHeaderValue = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${oic_user}:${oic_pass}"))
    Write-Host "Encoded String: $ImportauthorizationHeaderValue"

    $ImportHeaders = @{ "Authorization" = "$ImportauthorizationHeaderValue" }
    Write-Host "AUthorization Headers set"

    ## Query Parameters...
    #$QueryParam = @{ "q"="{timewindow:'1d', startdate:'2020-05-01 00:00:00', enddate:'2020-06-01 00:00:00'}" }
    # Use in -Body $QueryParam

    ## Call the REST API to download the diagnostic log
    $importurl = "https://$url/ic/api/integration/v1/monitoring/logs/$log"
    Write-Host "Download logs from URL: $importurl"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $logFile = "diag_log$(get-date -f MMddyyyy).zip"
    Invoke-WebRequest -Uri $importurl -Headers $ImportHeaders -Method GET -OutFile $logFile
    Write-Host "-------------------------- Logs Download Complete ------------------------"

    Expand-Archive -Path $logFile -DestinationPath "logs"
    cd logs
    
    ## Find ics-flow log files and move all occurances of them to OICS_LOGS folder one by one...
    $counter = 1
    Get-ChildItem -Path . -Recurse | ? {  $_.Name -like "*ics-flow*" } | ForEach-Object {
        $r = "Base Name: "+$_.BaseName+ " and Full Name: "+$_.FullName
        Write-Host $r
        $logBaseName = $_.BaseName+"_"+$counter+$_.Extension
        $counter++
        Write-Host "Modified File Name: $logBaseName"

        #if file exists rename it with date
        if( Test-Path -Path "$logFolder/$logBaseName" ){
            Write-Host "Renaming old file - $logBaseName......"
            $moveLogName = "$logBaseName"+"$(get-date -f MMddyyyy)"
            Try{
                Move-Item -Path "$logFolder/$logBaseName" -Destination "$logFolder/$moveLogName"
            }catch{
                $ErrorMessage = $_.Exception.Message
                Write-Host "##vso[task.logissue type=warning]$ErrorMessage"
                Write-Host "****** Ignoring this error ******"
            }
            
        }
        #Copy File to OICS_LOGS folder
        Copy-Item -Path $_.FullName -Destination "$logFolder/$logBaseName"
    }

    <#
    Write-Host "Moving $logFile to $logFolder...."
    Copy-Item -Path $logFile -Destination $logFolder
    #>

    Write-Host "---------------------Print $logFolder Contents---------------------"
    Get-ChildItem -Path $logFolder | ForEach-Object {
        Write-Host $_.FullName
    }
    Write-Host "--------------------------------------------------------------------"

    dir

}catch {

    Write-Host "The Powershell failed with: $LastExitCode"
	$ErrorMessage = $_.Exception.Message
    $Exception_line_num = $_.InvocationInfo.ScriptLineNumber
    Write-Host  "##vso[task.logissue type=error]Unhandled Exception,$ErrorMessage..occurred in the Powershell script line number : $Exception_line_num"
	throw "$ErrorMessage"
}