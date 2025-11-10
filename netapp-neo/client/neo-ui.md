
# Neo v3 for testing

This guide provides the necessary steps to deploy a "battery-included" Neo instance, using Docker or Podman, for **DEVELOPMENT and TESTING**, that includes:

- an official postgres instance, version 16.10-alpine3.21 
- version 3.0.4 of Neo 
- version 3.0.4 of Neo UI

For testing purposes, a local SAMBA service is also be included. 

> [!IMPORTANT]
> This guide leverage ```podman``` as a container runtime which calls for ```sudo``` due to its rootless nature and Neo needing rootful permissions to
> mount the shares.    
> When using ```docker```, just replace ```sudo podman``` by ```docker```.

## Deployment Guide

Create a directory called "neo-test" within your home directory tree or any location of your choice to host all the below configuration files.

### Environment variables
First we need to setup the following .env file to capture the necessary information such licensing and MS Graph details if M365 Copilot is a potential use case. 

```INI
# NetApp Settings (Required)
NETAPP_CONNECTOR_LICENSE=

# Microsoft Graph configuration (Required)
MS_GRAPH_CONNECTOR_ID=neoconnectortest                                          # <== Needs to be changed!    
#MS_GRAPH_CLIENT_ID=""                                                          
#MS_GRAPH_CLIENT_SECRET=""
#MS_GRAPH_TENANT_ID=""

# Database Configuration (Required- PostgreSQL is recommended)
DB_TYPE=postgres                                                                # Options postgres, mysql
## For PostgreSQL:
DATABASE_URL=postgresql://postgres:neodbsecret@neodb:5432/neoconnectortest      # <== Needs to be changed! 
## or for MySQL:
#DATABASE_URL=mysql://user:password@localhost:3306/netapp_connector

# Authentication (Optional - defaults provided)
#JWT_SECRET_KEY=your-secret-key-here
#ACCESS_TOKEN_EXPIRE_MINUTES=1440

# Multi-container deployments (Optional)
#ENCRYPTION_KEY=your-shared-encryption-key
```

### Deploy

```YAML
services:

  neodb:
    image: docker.io/library/postgres:16.10-alpine3.21
    container_name: neodb
    environment:      
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: neodbsecret
      POSTGRES_DB: neoconnectortest
    ports:
      - 5432:5432
    networks:
      - netapp-neo
    volumes:
      - neodb:/var/lib/postgresql/data
    restart: unless-stopped

  neo:
    image: ghcr.io/netapp/netapp-copilot-connector:3.0.4 
    container_name: neo
    # deploy: # Uncomment this section to enable GPU support
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: 1 # Adjust count based on your GPU availability
    #           capabilities: [gpu]
    cap_add:
      - SYS_ADMIN
      - DAC_READ_SEARCH
      - DAC_OVERRIDE
    security_opt:
      - apparmor:unconfined
    ports:
      - "8081:8080"
    networks:
      - netapp-neo      
    env_file:
      - .env
    environment:
      - PORT=8080
      - PYTHONUNBUFFERED=1
      - DB_PATH=data/database.db
      - MS_GRAPH_CLIENT_ID=${MS_GRAPH_CLIENT_ID}
      - MS_GRAPH_CLIENT_SECRET=${MS_GRAPH_CLIENT_SECRET}
      - MS_GRAPH_TENANT_ID=${MS_GRAPH_TENANT_ID}
      - MS_GRAPH_CONNECTOR_ID=${MS_GRAPH_CONNECTOR_ID:-netappcopilot}
      - MS_GRAPH_CONNECTOR_NAME=${MS_GRAPH_CONNECTOR_NAME:-"NetApp Connector"}
      - NETAPP_CONNECTOR_LICENSE=${NETAPP_CONNECTOR_LICENSE}

  neoui:
    image: ghcr.io/beezy-dev/neo-ui-framework:3.0.4
    container_name: neoui
    ports:
      - "8080:80"
    environment:
      - NEO_API=http://neo:8080   # ← add this
    networks:
      - netapp-neo
    restart: unless-stopped

  neosmb:
    image: docker.io/dockurr/samba
    container_name: neosmb
    environment:
      NAME: "data"
      USER: "smb"
      PASS: "smb"
      UID: 1000
      GID: 1000
    ports:
      - 445:445
    networks:
      - netapp-neo      
    volumes:
      - neosmb:/storage
    restart: unless-stopped

networks:
  netapp-neo:
    driver: bridge

volumes:
  neodb:
    driver: local
  neosmb:
    driver: local
``` 

Then start:
```BASH
sudo podman compose -f neo-all-in.yml up -d
```

Verify that all containers are started and running:
```BASH
sudo podman ps
```
Expected output:
```BASH
ONTAINER ID  IMAGE                                          COMMAND         CREATED         STATUS         PORTS                   NAMES
5eb9df04e9dd  docker.io/library/postgres:16.10-alpine3.21    postgres        12 minutes ago  Up 12 minutes  0.0.0.0:5432->5432/tcp  neodb
2eaffee6a8c0  ghcr.io/netapp/netapp-copilot-connector:3.0.4                  12 minutes ago  Up 12 minutes  0.0.0.0:8081->8080/tcp  neo
78b5ea86b582  ghcr.io/beezy-dev/neo-ui-framework:3.0.4       /entrypoint.sh  12 minutes ago  Up 12 minutes  0.0.0.0:8080->80/tcp    neoui
873d425a8179  docker.io/dockurr/samba:latest                                 12 minutes ago  Up 12 minutes  0.0.0.0:445->445/tcp    neosmb
```

#### Admin Password
> [!IMPORTANT]
> This temporary password will not appear again if you restart the container. If you failed to capture it, stop
> both neodb and neo containers, delete the neodb container and volume, and restart from step one.

At the first run, recover the temporary ```admin``` password in the container logs:

```bash
docker logs neo
``` 
Expected output:
```LOG
....
2025-11-10 09:32:54.841 | INFO     | app.enumeration_crawler:start:1133 - EnumerationFirstCrawler started successfully
2025-11-10 09:32:54.841 | INFO     | app.main:lifespan:202 - EnumerationFirstCrawler started successfully
2025-11-10 09:32:55.049 | INFO     | app.main:lifespan:230 -
==================== AUTO-GENERATED ADMIN ACCOUNT ====================
Username: admin
Password: 7e;2?r><kT&7At:x]j^(
====================================================================
Please log in and change this password immediately!


╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    ✅ NetApp NEO Connector Started Successfully!                            ║
║                                                                              ║
║    🌐 API Server: Ready                                                      ║
║    📊 Database: Initialized                                                  ║
║    🔗 Microsoft Graph: Connected                                             ║
║    📁 SMB Virtual File System: Ready                                         ║
║                                                                              ║
║    Ready to serve Microsoft 365 Copilot requests!                            ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

2025-11-10 09:32:55.049 | INFO     | app.background_task_manager:submit_task:138 - Submitted background task 8c740c66-6ddb-4650-b65d-dd980e17835b: schedule_existing_shares
2025-11-10 09:32:55.049 | INFO     | app.main:lifespan:302 - ⚡ Share scheduling started in background (task_id: 8c740c66-6ddb-4650-b65d-dd980e17835b)
....
```

#### Access the UI

Open a browser and point to your host IP on port 8080 like so: http://192.168.122.245:8080 or http://myhost.mydomain.tld:8080
Make sure that you don't have any firewall rules blocking you. 

The first page will indicate how to login using the password you have recovered, then go in ```Users``` and change your password.

## Troubleshooting

### postgres

Check if the DB was created using both method to verify DB and networking at the same time:

- ```sudo podman exec -it neodb psql -h localhost -U postgres -l```     
- ```psql -U postgres -h 192.168.122.245 -p 5432 postgres -l``` 

Expected output:
```                                                           List of databases
        Name        |  Owner   | Encoding | Locale Provider |  Collate   |   Ctype    | ICU Locale | ICU Rules |   Access privileges
--------------------+----------+----------+-----------------+------------+------------+------------+-----------+-----------------------
 netappconnectorrom | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8 |            |           |
 postgres           | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8 |            |           |
 template0          | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8 |            |           | =c/postgres          +
                    |          |          |                 |            |            |            |           | postgres=CTc/postgres
 template1          | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8 |            |           | =c/postgres          +
                    |          |          |                 |            |            |            |           | postgres=CTc/postgres
(4 rows)

``` 

### Neo

Check the logs to and share these with the team for any potential issues you might encounter:
```bash
sudo podman logs -f neo
```

### Neo UI 

Check the logs to and share these with the team for any potential issues you might encounter:
```bash
sudo podman logs -f neo
```

Check the web console in Browser for additional error messages.


### Samba (optional)

Check the logs to and share these with the team for any potential issues you might encounter:
```bash
sudo podman logs -f neo
```

