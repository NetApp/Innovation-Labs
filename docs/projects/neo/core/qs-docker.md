# Deploy using Docker

It is recommended to use Docker Compose for deploying the NetApp Connector (Neo) using Docker. Docker Compose simplifies the deployment process by allowing you to define and manage multi-container Docker applications with a single configuration file.

## Prerequisites

Before deploying the NetApp Connector (Neo) using Docker Compose, ensure that you have the following prerequisites in place:

- Docker installed on your system. You can download Docker from the [official Docker website](https://www.docker.com/get-started).
- Docker Compose installed. You can find installation instructions on the [Docker Compose installation page](https://docs.docker.com/compose/install/).
- Sufficient system resources to run the NetApp Connector (Neo). Refer to the [Sizing Guide](deployment#sizing-guide) in the Deployment section for recommended specifications.

## Deployment Steps

1. **Download the Docker Compose File**:
   Download the latest `docker-compose.yml` file from the [NetApp Neo GitHub repository](https://raw.githubusercontent.com/NetApp/Innovation-Labs/refs/heads/main/netapp-neo/dist/docker-compose.yml) to your local machine.
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
   docker-compose up -d
   ```
   This command will download the necessary Docker images and start the NetApp Connector (Neo) along with its dependencies in detached mode.
4. **Verify the Deployment**:
   After the containers are up and running, you can verify the deployment by checking the logs:

   ```bash
   docker-compose logs -f
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
docker-compose down
```

This command will stop and remove the containers and networks created by Docker Compose. Data will be preserved in the volumes defined in the `docker-compose.yml` file.

This concludes the steps to deploy the NetApp Connector (Neo) using Docker Compose. For more advanced configurations and management options, please refer to the [Management](management) section of the documentation.