# Deploy using Podman

It is recommended to use Podman Compose for deploying the NetApp Connector (Neo) using Podman. Podman Compose simplifies the deployment process by allowing you to define and manage multi-container Podman applications with a single configuration file, similar to Docker Compose.

## Prerequisites

Before deploying the NetApp Connector (Neo) using Podman Compose, ensure that you have the following prerequisites in place:

- Podman installed on your system. You can download Podman from the [official Podman website](https://podman.io/getting-started/installation).
- Podman Compose installed. You can install it using pip: `pip3 install podman-compose` or refer to the [Podman Compose installation instructions](https://github.com/containers/podman-compose).
- Sufficient system resources to run the NetApp Connector (Neo). Refer to the [Sizing Guide](deployment#sizing-guide) in the Deployment section for recommended specifications.

## Deployment Steps

1. **Download the Docker Compose File**:
   Download the latest `docker-compose.yml` file from the [NetApp Neo GitHub repository](https://raw.githubusercontent.com/NetApp/Innovation-Labs/refs/heads/main/netapp-neo/dist/docker-compose.yml) to your local machine. Podman Compose uses the same YAML format as Docker Compose.

2. **Configure Environment Variables**:
   Open the `docker-compose.yml` file in a text editor and configure the necessary environment variables, such as database connection details, admin credentials, and any other required settings.

   ```yaml
   environment:
     - DATABASE_URL=postgresql://postgres:yourStrongPasswordHere!@db:5432/neo
   ```

   For example, if my server's IP address is `10.100.20.05`, my username is `postgres`, the port is `5432` and my password is `yourStrongPasswordHere!`, I would set the `DATABASE_URL` as follows:

   ```yaml
   environment:
     - DATABASE_URL=postgresql://postgres:yourStrongPasswordHere!@10.100.20.05:5432/neo
   ```

3. **Start the Containers**:
   Open a terminal, navigate to the directory where the `docker-compose.yml` file is located, and run the following command to start the containers:
   ```bash
   podman-compose up -d
   ```
   This command will download the necessary container images and start the NetApp Connector (Neo) along with its dependencies in detached mode.

4. **Verify the Deployment**:
   After the containers are up and running, you can verify the deployment by checking the logs:

   ```bash
   podman-compose logs -f
   ```

   You should see logs indicating that the NetApp Connector (Neo) has started successfully as follows:

   ```
   neo-1  | 2025-12-03 19:46:43.882 | INFO     | app.main:lifespan:146 - Starting up application...
   neo-1  | 2025-12-03 19:46:43.882 | INFO     | app.main:lifespan:150 - 🔧 Setup mode: Skipping license validation and Graph initialization
   neo-1  | 2025-12-03 19:46:43.882 | INFO     | app.main:lifespan:151 - 📋 Complete setup via /api/v1/setup endpoints to enable full functionality
   neo-1  | INFO:     Application startup complete.
   neo-1  | INFO:     Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
   ```

5. **Access the Web Interface**:
   Open your web browser and navigate to `http://<your-server-ip>:8080` to access the NetApp Connector (Neo) web interface. Replace `<your-server-ip>` with the actual IP address of your server. For further information on using the web interface, refer to the [Management](management) section of the documentation.

## Stopping the Deployment

To stop the NetApp Connector (Neo) deployment, run the following command in the terminal where the `docker-compose.yml` file is located:

```bash
podman-compose down
```

This command will stop and remove the containers and networks created by Podman Compose. Data will be preserved in the volumes defined in the `docker-compose.yml` file.

## Podman-Specific Notes

- Podman runs containers rootless by default, providing enhanced security compared to Docker.
- Podman does not require a daemon to be running, unlike Docker.
- If you encounter permission issues with volumes, you may need to adjust SELinux contexts or volume mount options. Refer to the [Podman documentation](https://docs.podman.io/en/latest/) for troubleshooting.

This concludes the steps to deploy the NetApp Connector (Neo) using Podman Compose. For more advanced configurations and management options, please refer to the [Management](management) section of the documentation.