# Troubleshooting

## How to log a support case / idea

Please log support cases or ideas via the NetApp Innovations Labs issues portal: [Innovation Labs Issues](https://github.com/NetApp/Innovation-Labs/issues).

## Container won't start

This typically occurs when the connector does not have a valid license key. Ensure that the `NETAPP_CONNECTOR_LICENSE` environment variable is set in the .env file and that the license key is valid.