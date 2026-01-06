# Configuration

This guide assumes you have already reviewed the [Prerequisites](../prerequisites) and [Quick Start](../quick-start) guides.

When the connector is deployed it will deploy in SETUP mode by default. This allows you to complete the initial configuration of the connector via the API or web console. Once the connector is configured it can be switched to PRODUCTION mode.

<blockquote style="background-color: #e7f3ff; border-left: 4px solid #2196F3; padding: 10px; margin: 10px 0;">
<strong>📘 Note:</strong> The following guidance is temporary and will be native in Neo Console in a future release. During this time please follow the steps below to switch between modes and configure your license.
</blockquote>

## How to check which mode the connector is in

```bash
curl --location 'yourConnectorIpAddress:8081/api/v1/setup/status'
```

The connector will respond with the following:

```json
{
  "setup_complete": false,
  "database_configured": true,
  "database_url_environment_set": true,
  "config_storage": "database",
  "steps_completed": [],
  "required_steps": ["license"],
  "optional_steps": ["graph", "ssl", "proxy", "performance"],
  "message": "Setup in progress: 1/1 required steps completed.",
  "persistence_info": {
    "database_url_set": true,
    "persistent": true,
    "message": "Configuration is stored in database and will persist across restarts."
  }
}
```

It is required to configure a valid license before switching to PRODUCTION mode.

## How to add your license

You can add your license via the API as follows:

```bash
curl --location 'yourConnectorIpAddress:8081/api/v1/setup/license' \
--header 'Content-Type: application/json' \
--data '{
    "license_key": "yourlicensekey"
}'
```

You should receive a response similar to the following:

```json
{
  "success": true,
  "message": "License configured successfully."
}
```

If you are not connecting to Microsoft Graph you can now switch to PRODUCTION mode. If you are connecting to Microsoft Graph please continue to the next section otherwise skip to the "Completing Setup" section.

## How to connect to Microsoft Graph

To connect to Microsoft Graph, you need to provide the necessary configuration via the API:

```bash
curl --location 'yourConnectorIpAddress:8081/api/v1/setup/graph' \
--header 'Content-Type: application/json' \
--data '{
    "tenant_id": "yourtenantid",
    "client_id": "yourclientid",
    "client_secret": "yourclientsecret",
    "connector_id": "netappneo",
    "connector_name": "NetApp NEO Connector",
    "connector_description": "This connector stores all of our private, enterprise files, information and intelligence that is not available publically."
}'
```

You should receive a response similar to the following:

```json
{
  "success": true,
  "message": "Microsoft Graph credentials configured successfully."
}
```

## Completing Setup: How to switch to PRODUCTION mode

Once all required steps are complete you can switch to PRODUCTION mode via the API:

```bash
curl --location --request POST '192.168.1.89:8081/api/v1/setup/complete'
```

You will recieve a response similar to the following:

```json
{
  "success": true,
  "message": "Setup completed successfully. Application will restart automatically in 10 seconds.",
  "configured_steps": ["license", "graph"],
  "restart_countdown_seconds": 10,
  "database_url_configured": true,
  "note": "Optional steps not configured: ssl, proxy. You can configure these later via the setup API."
}
```

You have successfully switched the connector to PRODUCTION mode. You can now begin adding data sources and configuring ingestion jobs via the web console or API. Please refer to the [Management](https://netapp.github.io/netapp-connector-docs/management.html) section for further information.