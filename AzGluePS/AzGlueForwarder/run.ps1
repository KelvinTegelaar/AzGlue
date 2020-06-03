using namespace System.Net
param($Request, $TriggerMetadata)

#Check if the client's API token matches our stored version and that it's not too short.
#Without this check, an empty or missing environmental variable would allow unauthenticated access.
if ($request.Headers.'x-api-key' -eq $ENV:AzAPIKey -and $ENV:AzAPIKey.Length -gt 12) {
    #Comparing the client IP to the Organization list, and checking if it exists.
    $ClientIP = ($request.headers.'X-Forwarded-For' -split ':')[0]
    #When working locally set client IP to "    localtesting".
    if (-not $ClientIP -and $request.url.StartsWith("http://localhost:")) {
        $ClientIP = "localtesting"
    }
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
    #$resource = $request.params.path -replace "AzGlueForwarder/", ""

    #get the resource URI. "https?" allows it to work locally and remotely. Removing the trailing slash
    #now avoids issues later when we join the base URI and resource string with a forwardslash.  
    $resource = $request.url -replace "https?://$($ENV:WEBSITE_HOSTNAME)/API/", ""
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
 
    #Where possible, strip the data that does not belong to this client. 
    #Important so passwords/items can only be retrieved belonging to this organisation.
    #Can't do it for all requests.
 
    # I've updated this code so that it filters organizations as well as config/password/flex assets. 
    # There is a bug in the original "$ITGlueRequest.data.attributes.'organization-id'" check which will filter some records unintuitively.
    # If you request data from an object which doesn't contain the .data.attributes.'organization-id' property, and only returns
    # a single record, it will be returned to the client. If you request data from the same object but IT Glue returns multiple 
    # records, they will all be excluded from the returned data. This is because IT Glue wraps multiple records in an array of data 
    # records, and when checking to see if the attribute is set, PowerShell returns an array or nulls, which is not equal to null, 
    # and so passes the check. I am not fixing the bug because I intend to restrict this further anyway, and until then I don't want
    # to expose more data than the original function does.
    # this would fix it: if ($ITGlueRequest.data[0].attributes.'organization-id' -or ...

    if ($ITGlueRequest.data.attributes.'organization-id' -or $ITGlueRequest.data.type -contains "organizations") {
        $ITGlueRequest.data = $ITGlueRequest.data | Where-Object {
            ($_.type -eq "organizations" -and $_.id -in $AllowedOrgs.ITGlueOrgID) -or
            ($_.attributes.'organization-id' -in $AllowedOrgs.ITGlueOrgID)
        }
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