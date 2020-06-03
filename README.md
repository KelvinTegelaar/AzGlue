# AzGlue, a secure API gateway for IT Glue
This project has been forked from [Kelvin Tegelaar](https://github.com/KelvinTegelaar)'s repo hosted on [KelvinTegelaar/AzGlue](https://github.com/KelvinTegelaar/AzGlue) and originally posted to his (fantasic) blog [cyberdrain.com](https://www.cyberdrain.com/documenting-with-powershell-handling-it-glue-api-security-and-rate-limiting/).

I'll be aiming to implement the following features to improve the security:
- [x] Allow local dev, testing and deployment with VSCode's [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions).
- [x] Prevent misconfigured gateways from accepting empty API keys.
- [x] Restrict returned data from the /organizations endpoint to honor OrgId whitelisting.
- [ ] Allow clients to post new passwords without allowing them to retrieve existing passwords.
- [ ] Allow whitelisting specific API endpoints.
- [ ] When relaying requests, allow per-endpoint filtering and validation of:
  - [ ] Supported HTTP methods (POST/PATCH/PUT/DELETE).
  - [ ] Query string paramaters.
  - [ ] Payload data sent to IT Glue.
  - [ ] Payload data returned to the client.
- [ ] Per-client API keys  
- [ ] System to restrict returned data relevant to the specific client PC making the request. 
- [ ] Move IT Glue API key to Azure Key Vault.


## Original README
See https://www.cyberdrain.com/documenting-with-powershell-handling-it-glue-api-security-and-rate-limiting/ for more information.

After my previous blogs the comment I’ve received most was worries about the API key. If they key gets stolen you’re giving away the keys to the castle. The API has no limitations and with a leaked key all your documentation could be download. I’ve been discussing this issue with IT-Glue for some time but haven’t gotten a real solution yet. This has forced me to look for a solution myself. I gave myself some requirements for the solution.

- The solution needed to be simple and accessible for everyone.
- The solution needed to have multiple levels of authentication; an API key, IP whitelisting, and organization whitelisting.
- The solution needed to block requests for all passwords/files/etc for all organisations.
- The solution needed to allow some form of handling of the API rate limiting, e.g. repeating a request if it was rate limited.
- The solution needed to be able to used, without adapting any scripts (except URLs and API codes.)
- So after some research I decided to use an Azure Function for this. I’ve blogged about Azure Functions before, but the main reason is that running this function in the consumption model will cost us nothing (or next to nothing if you are an extremely heavy user.)

