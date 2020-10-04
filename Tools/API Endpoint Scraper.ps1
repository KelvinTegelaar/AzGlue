Import-Module powershell-yaml

$resp = Invoke-WebRequest "https://api.itglue.com/developer/"
$apiDivs = $resp.ParsedHtml.body.getElementsByTagName('div') | Where-Object {
    $_.getAttributeNode('class').Value -like "page__apiv1*__*"
}

$data = [ordered]@{}
$dataCombined = [ordered]@{}

foreach ($item in $apiDivs) {
    $regex = [regex]::Matches($item.className, 'page__apiv1(([^ ]*)__([^ ]*))')
    $matches = $regex.Groups.Value
    $apiNameFull = $matches[1]
    $apiNamePartial = $matches[2]
    $apiMethodLabel = $matches[3]

    if (-not $labelFull) {
        Write-Host "No match: $($item.className)"
        continue
    }
    $heading = $item.getElementsByTagName("H1")[0].innerText -split ' '
    $method = $heading[0]
    $endpoint = $heading[1] -replace "/:[^/]+","/:id"
    $requestBody = @()
    $requestBodyError = @()
    $responseBody = @()
    $responseBodyError = @()

    $preBlocks = $item.getElementsByTagName("PRE")
    foreach ($preBlock in $preBlocks) {
        $previousSibling = $preBlock.previousSibling
        if ($previousSibling.innerText -match "request|create") {
            try { 
                $requestBody += "{ $($preBlock.innerText) }" | convertfrom-json
            } catch {
                $requestBodyError += $preBlock.innerText
            }
        } elseif ($previousSibling.innerText -match "response|return") {
            try {
                $responseBody += "{ $($preBlock.innerText) }" | convertfrom-json
            } catch {
                $responseBodyError += $preBlock.innerText
            }
        }
    }
    
    $filters = @()
    foreach ($table in $item.getElementsByTagName("TABLE")) {
        if ($table.previousSibling.innerText -like "*Param*") {
            foreach ($elem in $table.getElementsByTagName("STRONG")) {
                if ($elem.innerText -like "*filter*") {
                    $filters += $elem.innerText.trim()
                }
            }
        }
    }
    $filters = $filters | sort | get-unique

    $data[$apiNameFull] = [ordered]@{
        endpoints = @($endpoint) | sort | get-unique
        methods = @($method) | sort | get-unique
        allowed_parameters = @($filters)
        required_parameters = @()
        requestbody = $requestBody | sort | get-unique
        responsebody = $responseBody | sort | get-unique
        requestbodyError = $requestBodyError | sort | get-unique
        responsebodyError = $responseBodyError | sort | get-unique
    }

    $dc = $dataCombined[$apiNamePartial]
    $dc = [ordered]@{
        endpoints =           @($dc.endpoints) + @($endpoint) | sort | get-unique
        methods =             @($dc.methods) + @($method) | sort | get-unique
        #apiLabels =          @($dc.apiLabels) + @($apiMethodLabel) | sort | get-unique
        allowed_parameters =  @($dc.allowed_parameters) + @($filters) | sort | get-unique
        required_parameters = @()
        requestbody =         @($dc.requestbody) + $requestBody | sort | get-unique
        responsebody =        @($dc.responsebody) + $responseBody | sort | get-unique
        requestbodyError =    @($dc.requestbodyError) + $requestBodyError | sort | get-unique
        responsebodyError =   @($dc.responsebodyError) + $responseBodyError | sort | get-unique
    }
    $dataCombined[$apiNamePartial] = $dc
}