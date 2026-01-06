# Neo Console

## Access the web management interface

The web interface can be accessed by navigating to `http://<server-ip>:8080` in your web browser, where `<server-ip>` is the IP address of the server where the NetApp Connector (Project Neo) is deployed. If you are using ingress, use the appropriate URL configured for access.

If the web interface is not accessible, ensure that the server is running and that there are no firewall rules blocking access to port 8080.

On first access, you will be prompted to log in. Use the default credentials provided during installation. It is highly recommended to change the default password upon first login for security purposes. If you have forgotten your password, please run the following command to retrieve the auto-generated admin password:

```bash
curl --location '192.168.1.89:8081/api/v1/setup/initial-credentials'
```

<blockquote style="background-color: #e7f3ff; border-left: 4px solid #2196F3; padding: 10px; margin: 10px 0;">
<strong>📘 Note:</strong> The above command will only work if the admin user has never logged in before. If the admin user has logged in previously, you will need to reset the password via the API or database.
</blockquote>

## Search

[Add search functionality information]

## Operations

[Add operations information]