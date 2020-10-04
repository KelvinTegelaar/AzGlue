# AzGlue, a secure API gateway for IT Glue

This project was made by [Kelvin Tegelaar](https://github.com/KelvinTegelaar)'s repo hosted on [KelvinTegelaar/AzGlue](https://github.com/KelvinTegelaar/AzGlue) and originally posted to his on blog [cyberdrain.com](https://www.cyberdrain.com/documenting-with-powershell-handling-it-glue-api-security-and-rate-limiting/).

The current version is a result of merging Angus Warrens version with many security improvements, and [Anguswarren/AzGlue](https://github.com/AngusWarren/AzGlue) and Kelvin's repo.

The current release tries to maintain backwards compatibilty with Kelvin's existing gateway and public scripts. In the future, There might be changes that require deeper moditifation of the AzGlue function which does not allow to retain backwards compatbility. 

### Lite Branch:
 The lite branch is the version that was published on the blog originally. Per requests I've made this version available for everyone just getting started or not requiring whitelisting of each endpoint.

### Basic setup
Automatic:
1. Click on "Deploy on Azure" right here. 

Manual:
1. Install the [Azure Functions extensions](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions) for VS Code.
2. Copy the local.settings.json.example file, and remove the .example extension. 
3. Populate the AzAPIKey, ITGlueAPIKey & ITGlueURI environmental variables here.
4. Copy OrgList.csv.example and remove the .example extension.
5. Update to match your environment.
6. Right click on the "AzGluePS" direction, and select "open with Code"
7. Open the "run.ps1" file and press F5. 
8. Test it locally using the "http://localhost:7071/api/${functionName}?ResourceURI=" URI.
9. Open the Azure tab on the left, open Functions, click the "Deploy to Function App.." button to create/deploy the app in Azure.
11. Open the App Service in the Azure Portal, and enable a system managed identity from Settings > Identity. 
10. Set up application settings:
    1. Open the Azure portal, open your App Service, open Configuration > Application settings.
    2. Add AzAPIKey, ITGlueAPIKey & ITGlueURI environmental variables here. 
    3. If you've got a Key Vault, you can authorise the system managed identity and provide access to the key through the Application settings [using this process](https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references)

### Basic usage:
Once the gateway is deployed to Azure Functions, you can use the standard IT Glue Powershell module to query it.
```PowerShell
Import-Module ITGlueAPI
Add-ITGlueBaseUri "https://FUNCTIONNAME.azurewebsites.net/api/"
Add-ITGlueApiKey "random_password_saved_in_functions_environmental_variables"

Get-ITGluePasswords -organization_id 1234
```


### Original README
See https://www.cyberdrain.com/documenting-with-powershell-handling-it-glue-api-security-and-rate-limiting/ for more information.

After my previous blogs the comment I’ve received most was worries about the API key. If they key gets stolen you’re giving away the keys to the castle. The API has no limitations and with a leaked key all your documentation could be download. I’ve been discussing this issue with IT-Glue for some time but haven’t gotten a real solution yet. This has forced me to look for a solution myself. I gave myself some requirements for the solution.

- The solution needed to be simple and accessible for everyone.
- The solution needed to have multiple levels of authentication; an API key, IP whitelisting, and organization whitelisting.
- The solution needed to block requests for all passwords/files/etc for all organisations.
- The solution needed to allow some form of handling of the API rate limiting, e.g. repeating a request if it was rate limited.
- The solution needed to be able to used, without adapting any scripts (except URLs and API codes.)
- So after some research I decided to use an Azure Function for this. I’ve blogged about Azure Functions before, but the main reason is that running this function in the consumption model will cost us nothing (or next to nothing if you are an extremely heavy user.)

### Contributions & Thanks

The project is open to any PR and/or direct contributors. Feel free to contact kelvin (at) cyberdrain.com if you'd like to be a direct contributor. Special thanks goes out to [AngusWarren](https://github.com/AngusWarren) for the amazing changes to the security of the AzGlue function. 
