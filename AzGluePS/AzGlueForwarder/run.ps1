using namespace System.Net
param($Request, $TriggerMetadata)

# TEMP: DEBUG
Write-Host ($request | convertto-json -depth 5)

Function ImmediateFailure ($message) {
    Write-Host $message
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        headers    = @{'content-type' = 'application\json' }
        StatusCode = [httpstatuscode]::OK
        Body       = @{"Error" = $message } | convertto-json
    })
    exit 1
}

function Build-Body ($whitelistObj, $sourceObj) {
    if (-not $sourceObj) {
        Return
    }
    if ($whitelistObj -is [hashtable] -or $whitelistObj -is [System.Collections.Specialized.OrderedDictionary]) {
        $newObject = @{}
        foreach ($key in $whitelistObj.keys) {
            if ($sourceObj.$key) {
                $newObject[$key] = Build-Body $whitelistObj[$key] $sourceObj.$key
            }
        }
    } elseif ($whitelistObj -is [System.Collections.Generic.List`1[System.Object]]) {
        $newObject = @()
        foreach ($item in $sourceObj) {
            $newObject += Build-Body $whitelistObj[0] $item
        }
    } elseif ($whitelistObj -is [string]) {
        $newObject = $sourceObj
    } else {
        Write-Error "Unexpected type found $whitelistObj"
    }
    Return $newObject
}

$clientToken = $request.headers.'x-api-key'

# Check if the client's API token matches our stored version and that it's not too short.
# Without this check, a misconfigured environmental variable could allow unauthenticated access.
# TODO: Set up a unique key per client, with each key linked to an array of org IDs and IP addresses.
if ($ENV:AzAPIKey.Length -lt 14 -or $clientToken -ne $ENV:AzAPIKey) {
    ImmediateFailure "401 - API token does not match"
}

# Get the client's IP address
$ClientIP = ($request.headers.'X-Forwarded-For' -split ':')[0]
if (-not $ClientIP -and $request.url.StartsWith("http://localhost:")) {
    $ClientIP = "localtesting"
}
# Check the client's IP against the IP/org whitelist.
$OrgList = import-csv "AzGlueForwarder\OrgList.csv" -delimiter ","
$AllowedOrgs = $OrgList | where-object { $_.ip -eq $ClientIP }
if (!$AllowedOrgs) { 
    ImmediateFailure "No match found in allowed list"
}

## Whitelisting endpoints & data.
# TODO: This takes about 800ms to import the first time. Need to confirm that subsequent queries are faster.
Measure-Command { Import-Module powershell-yaml -Function ConvertFrom-Yaml }
$endpoints = Get-Content .\whitelisted-endpoints.yml | ConvertFrom-Yaml

$resourceUri = $request.Query.ResourceURI
$resourceUri_generic = ([string]$resourceUri).TrimEnd("/") -replace "/\d+","/:id"

# Check to see if the called API endpoint & method has been whitelisted.
foreach ($key in $endpoints.keys) {
    if ($endpoints[$key].endpoints -contains $resourceUri_generic -and $endpoints[$key].methods -contains $request.Method) {
        $endpointKey = $key
        break
    }
}
if (-not $endpointKey) {
    ImmediateFailure "401 - Unauthorized endpoint or method"
}

# Build new query string from required and whitelisted parameters
$itgQuery = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
foreach ($filter in $endpoints[$endpointKey].required_parameters.Keys) {
    Write-Host $filter
    $itgQuery.Add($filter, $endpoints[$endpointKey].required_parameters.$filter)
}
foreach ($filter in $endpoints[$endpointKey].allowed_parameters) {
    Write-Host $filter
    if ($request.Query.$filter) {
        $itgQuery.Add($filter, $request.Query.$filter)
    }
}

# Combine resource URI and query string
$uriBuilder = [System.UriBuilder]("{0}{1}" -f $ENV:ITGlueURI,$resourceUri)
$uriBuilder.Query = $itgQuery.ToString()
$itgUri = $uriBuilder.Uri.OriginalString

# Construct new request for IT Glue
# TODO: Move this to Key Vault
$itgHeaders = @{"x-api-key" = $ENV:ITGlueAPIKey}
$itgMethod = $Request.method
$oldBody = $request.body | convertfrom-json
$itgBody = Build-Body $endpoints[$endpointKey].createbody $oldBody
$itgBodyJson = $itgBody | ConvertTo-Json -Depth 5
Write-Information "Outgoing body: $itgBodyJson"

# Send request to IT Glue
$SuccessfullQuery = $false
$attempt = 2
while ($attempt -gt 0 -and -not $SuccessfullQuery) {
    try {
        $itgRequest = Invoke-RestMethod -Method $itgMethod -ContentType "application/vnd.api+json" -Uri $itgUri -Body $itgBodyJson -Headers $itgHeaders
        $SuccessfullQuery = $true
    } catch {
        $attempt--
        if ($attempt -eq 0) {
            # don't include $_.Exception.Message to avoid leaking any unexpected information.
            ImmediateFailure "$($_.Exception.Response.StatusCode.value__) - Failed after 3 attempts to $itgUri." 
        }
        start-sleep (get-random -Minimum 0 -Maximum 10)
    }
}

# For organization specific data, only return records linked to the authorized client.
if ($itgRequest.data.type -contains "organizations" -or 
    $itgRequest.data[0].attributes.'organization-id') {

    $itgRequest.data = $itgRequest.data | Where-Object {
        ($_.type -eq "organizations" -and $_.id -in $allowedOrgs.ITGlueOrgID) -or
        ($_.attributes.'organization-id' -in $allowedOrgs.ITGlueOrgID)
    }
}

# Strip out any paramaters from the body which haven't been explicitly whitelisted.
$itgReturnBody = Build-Body $endpoints[$endpointKey].returnbody $itgRequest
if ($itgRequest.meta) {$itgReturnBody.meta = $itgRequest.meta}
if ($itgRequest.links) {$itgReturnBody.links = $itgRequest.links}

# Return the final object.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    headers    = @{'content-type' = 'application\json' }
    StatusCode = [httpstatuscode]::OK
    Body       = $itgReturnBody
})