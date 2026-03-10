# Configuration

This guide assumes you have already reviewed the [Prerequisites](../prerequisites) and [Quick Start](../quick-start) guides.

When the connector is deployed it will deploy in SETUP mode by default. This allows you to complete the initial configuration of the connector via the API or web console. Once the connector is configured it can be switched to PRODUCTION mode.

## How to check which mode the connector is in

```bash
curl --location 'yourConnectorIpAddress:8000/api/v1/setup/status'
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
curl --location 'yourConnectorIpAddress:8000/api/v1/setup/license' \
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
curl --location 'yourConnectorIpAddress:8000/api/v1/setup/graph' \
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
curl --location --request POST 'yourConnectorIpAddress:8000/api/v1/setup/complete'
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

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| **Database** | | |
| `DATABASE_URL` | *(required)* | PostgreSQL or MySQL connection string |
| **Authentication** | | |
| `JWT_SECRET_KEY` | *(auto-generated)* | Secret key for signing JWT tokens |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` | JWT token expiry time in minutes |
| **Encryption** | | |
| `ENCRYPTION_KEY` | *(auto-generated)* | Fernet key for encrypting stored credentials |
| **License** | | |
| `NETAPP_CONNECTOR_LICENSE` | *(none)* | Pre-configure license key via environment |
| `CONNECTOR_ID` | *(auto-generated)* | Unique identifier for this connector instance |
| **Microsoft Graph** | | |
| `MS_GRAPH_TENANT_ID` | *(none)* | Azure AD tenant ID |
| `MS_GRAPH_CLIENT_ID` | *(none)* | Azure AD app registration client ID |
| `MS_GRAPH_CLIENT_SECRET` | *(none)* | Azure AD app registration client secret |
| `MS_GRAPH_CONNECTOR_ID` | `netappneo` | Microsoft Graph connector identifier |
| **MCP OAuth** | | |
| `MCP_OAUTH_ENABLED` | `false` | Enable OAuth authentication for MCP transport |
| `MCP_OAUTH_TENANT_ID` | *(none)* | Azure AD tenant ID for MCP OAuth |
| `MCP_OAUTH_CLIENT_ID` | *(none)* | Azure AD client ID for MCP OAuth |
| `MCP_OAUTH_CLIENT_SECRET` | *(none)* | Azure AD client secret for MCP OAuth |
| **MCP API Key** | | |
| `MCP_API_KEY` | *(none)* | Static API key for MCP transport authentication |
| **Worker Concurrency** | | |
| `NUM_UPLOAD_WORKERS` | `2` | Concurrent Graph upload workers |
| `NUM_EXTRACTION_WORKERS` | `2` | Concurrent content extraction workers |
| `NUM_ACL_RESOLUTION_WORKERS` | `2` | Concurrent ACL resolution workers |
| `NUM_NER_WORKERS` | `2` | Concurrent NER processing workers |
| **Extractor** | | |
| `EXTRACTOR_LOG_LEVEL` | `INFO` | Log level for the extractor service |
| `EXTRACTOR_DEFAULT_PIPELINE` | `markitdown` | Default extraction pipeline (`markitdown`, `docling`, `vlm`) |
| `EXTRACTOR_MOUNT_TTL` | `3600` | Seconds before unmounting idle share mounts |
| `EXTRACTOR_FORCE_CPU` | `false` | Force CPU-only mode even if GPU is available |
| `VLM_MODEL` | *(none)* | Vision-language model for VLM extraction pipeline |
| **NER** | | |
| `NER_MODEL_NAME` | `gliner-community/gliner_medium-v2.5` | GLiNER model for named entity recognition |
| `NER_CONFIDENCE_THRESHOLD` | `0.5` | Minimum confidence score for entity detection |
| `NER_MAX_TEXT_LENGTH` | `10000` | Maximum text length per NER request (CPU) |
| `NER_DEVICE` | `cpu` | Device for NER inference (`cpu`, `cuda`) |
| `NER_CUDA_MAX_TEXT_LENGTH` | `50000` | Maximum text length per NER request (GPU) |
| **SSL / Proxy** | | |
| `HTTPS_PROXY` | *(none)* | HTTPS proxy URL for outbound connections |
| `GRAPH_CA_BUNDLE` | *(none)* | Path to custom CA bundle for Graph API calls |
| `GRAPH_VERIFY_SSL` | `true` | Enable/disable SSL verification for Graph API |
