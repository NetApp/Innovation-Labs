
# Neo v3 for testing

This guide provides the necessary steps to deploy a "battery-included" Neo instance, using Docker or Podman, for **DEVELOPMENT and TESTING**, that includes:

- an official PostgreSQL instance, version 16.10-alpine3.21 
- version 3.0.4 of Neo 
- version 3.0.4 of Neo UI

For testing purposes, a local SAMBA service can also be included. 

## Deployment Guide

Create a directory called "neo-test" within your home directory tree or any location of your choice to host all the configuration files below.

### postgres

First, we need to set up a PostgreSQL database by creating the following ```neodb.yml```

```YAML
services:
  neodb:
    image: docker.io/library/postgres:16.10-alpine3.21
    container_name: neodb
    environment:      
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: neodbsecret
      POSTGRES_DB: neodb
    ports:
      - 5432:5432
    networks:
      - netapp-neo
    volumes:
      - neodb:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  neodb:
    driver: local

networks:
  neo:
    driver: bridge
```

Then start the database:
```BASH
docker compose -f neodb.yml up -d --build
```
Verify that the database is up and running
```BASH
docker exec -it neodb psql -h localhost -U postgres neodb
```

### Neo v3 instance

#### Environment variables
First, we need to set up the following .env file to capture the necessary information, such as licensing and MS Graph details, if M365 Copilot is a potential use case. 

```INI
# NetApp Settings (Required)
NETAPP_CONNECTOR_LICENSE=

# Microsoft Graph configuration (Required)
MS_GRAPH_CONNECTOR_ID=
#MS_GRAPH_CLIENT_ID=""
#MS_GRAPH_CLIENT_SECRET=""
#MS_GRAPH_TENANT_ID=""

# Database Configuration (Required- PostgreSQL is recommended)
DB_TYPE=postgres                                                            # Options postgres, mysql
## For PostgreSQL:
DATABASE_URL=postgresql://postgres:neodbsecret@neodb:5432/neodb
## or for MySQL:
#DATABASE_URL=mysql://user:password@localhost:3306/netapp_connector

# Authentication (Optional - defaults provided)
#JWT_SECRET_KEY=your-secret-key-here
#ACCESS_TOKEN_EXPIRE_MINUTES=1440

# Multi-container deployments (Optional)
#ENCRYPTION_KEY=your-shared-encryption-key
```

#### Container image

In the same directory where the .env file was created, create the following ```neo.yml``` file:


```YAML
services:

  neo:
    image: ghcr.io/netapp/netapp-copilot-connector:3.0.4 
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
    volumes:
      - neodata:/app/data
    restart: unless-stopped

volumes:
  neodata:
    driver: local

networks:
  neo:
    driver: bridge
```

Then start the Neo v3 instance:
```BASH
docker compose -f neo.yml up -d
```

### Neo UI 

In the same directory, create the following ```neoui.yml`` file:

```YAML
services:

  neoui:
    image: ghcr.io/beezy-dev/neo-ui-framework:3.0.4
    ports:
      - "8080:80"
    environment:
      - NEO_API=http://neo:8080   # ← add this
    networks:
      - neo
    restart: unless-stopped

networks:
  neo:
    driver: bridge
```

Then start the Neo v3 UI:
```BASH
docker compose -f neoui.yml up -d
```

### Samba (optional)

In the same directory, create the following ```neosmb.yml`` file:

```YAML
services:

  samba:
    image: docker.io/dockurr/samba
    container_name: samba
    environment:
      NAME: "data"
      USER: "smb"
      PASS: "smb"
      UID: 1000
      GID: 1000
    ports:
      - 445:445
    networks:
      - neo      
    volumes:
      - neosmb:/storage
    restart: unless-stopped

volumes:
  neosmb:
    driver: local

networks:
  neo:
    driver: bridge
```

Then start the optional **for testing only** Samba server:
```BASH
docker compose -f neosmb.yml up -d
```

## 1-file-deployment

In the same directory as the .env file, create the following ```neo-all-in.yml``` file: 

```YAML
services:

  neodb:
    image: docker.io/library/postgres:16.10-alpine3.21
    container_name: neodb
    environment:      
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: neodbsecret
      POSTGRES_DB: neodb
    ports:
      - 5432:5432
    networks:
      - netapp-neo
    volumes:
      - neodb:/var/lib/postgresql/data
    restart: unless-stopped

  neo:
    image: ghcr.io/netapp/netapp-copilot-connector:3.0.4 
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
    volumes:
      - neodata:/app/data
    restart: unless-stopped

  neoui:
    image: ghcr.io/beezy-dev/neo-ui-framework:3.0.4
    ports:
      - "8080:80"
    environment:
      - NEO_API=http://neo:8080   # ← add this
    networks:
      - neo
    restart: unless-stopped

  samba:
    image: docker.io/dockurr/samba
    container_name: samba
    environment:
      NAME: "data"
      USER: "smb"
      PASS: "smb"
      UID: 1000
      GID: 1000
    ports:
      - 445:445
    networks:
      - neo      
    volumes:
      - neosmb:/storage
    restart: unless-stopped

networks:
  neo:
    driver: bridge

networks:
  neo:
    driver: bridge

volumes:
  neodb:
    driver: local
  neodata:
    driver: local
  neosmb:
    driver: local
``` 

Then start:
```BASH
docker compose -f neo-all-in.yml up -d
```
