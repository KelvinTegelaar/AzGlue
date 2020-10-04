using namespace System.Net
param($Request, $TriggerMetadata)
#Check if AZapiKey is correct
if ($request.Headers.'x-api-key' -eq $ENV:AzAPIKey) {
    #Comparing the client IP to the Organization list, and checking if it exists.
    $ClientIP = ($request.headers.'X-Forwarded-For' -split ':')[0]
    $CompareList = import-csv "AzGlueForwarder\OrgList.csv" -delimiter ","
    $AllowedOrgs = $comparelist | where-object { $_.ip -eq $ClientIP }
    if (!$AllowedOrgs) { 
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                headers    = @{'content-type' = 'application\json' }
                StatusCode = [httpstatuscode]::OK
                Body       = @{"Error" = "401 - No match found in allowed list" } | convertto-json
            })
        exit 1
    }
  
    #Sending request to ITGlue
   
    $resource = $request.url -replace "https://$($ENV:WEBSITE_HOSTNAME)/API/", ""
    #Replace x-api-key with actual key
    $ITGHeaders = @{
        "x-api-key" = $ENV:ITGlueAPIKey
    } 
    $Method = $($Request.method)
    $ITGBody = $($Request.body)
    #write-host ($AllowedOrgs | out-string)
    $SuccessfullQuery = $false
    $attempt = 3
    while ($attempt -gt 0 -and -not $SuccessfullQuery) {
        try {
            $ITGlueRequest = Invoke-RestMethod -Method $Method -ContentType "application/vnd.api+json" -Uri "$($ENV:ITGlueURI)/$resource" -Body $ITGBody -Headers $ITGHeaders
            $SuccessfullQuery = $true
        }
        catch {
            $ITGlueRequest = @{'Errorcode' = $_.Exception.Response.StatusCode.value__ }
            $rand = get-random -Minimum 0 -Maximum 10
            start-sleep $rand
            $attempt--
            if ($attempt -eq 0) { $ITGlueRequest = @{'Errorcode' = "Error code $($_.Exception.Response.StatusCode.value__) - Made 3 attempts and upload failed. $($_.Exception.Message) / Resource was $($ENV:ITGlueURI)/$resource" } }
        }
    }
  
    #Checking if we can strip the data that does not belong to this client. 
    #Important so passwords/items can only be retrieved belonging to this organisation.
    #Can't do it for all requests, such as get-organisation, but for senstive data it works perfectly. :)
  
    if ($($ITGlueRequest.data.attributes.'organization-id')) {
        write-host ($AllowedOrgs.ITGlueOrgID)
        $ITGlueRequest.data = $ITGlueRequest.data | where-object { $_.attributes.'organization-id' -in $($AllowedOrgs.ITGlueOrgID) }    
    }
  
    #Sending the final object back to the client.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            headers    = @{'content-type' = 'application\json' }
            StatusCode = [httpstatuscode]::OK
            Body       = $ITGlueRequest
        })
  
  
}
else {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            headers    = @{'content-type' = 'application\json' }
            StatusCode = [httpstatuscode]::OK
            Body       = @{"Error" = "401 - No API Key entered or API key incorrect." } | convertto-json
        })
      
}