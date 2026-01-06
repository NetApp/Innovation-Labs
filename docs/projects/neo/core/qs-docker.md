
# Deploy using Docker/Podman

This guide provides the necessary steps to deploy a "battery-included" Neo instance, using Docker or Podman that includes:

- an official PostgreSQL instance, version 16.10-alpine3.21 
- version 3.1.1 of Neo 
- version 3.1.1 of Neo UI

For testing purposes, a local SAMBA service is also included. 

## Prerequisites

Before deploying the NetApp Connector (Neo) using Podman Compose, ensure that you have the following prerequisites in place:

::: details Docker
- Docker installed on your system. You can download Docker from the [official Docker website](https://www.docker.com/get-started/).
- Docker Compose installed. You can find installation instructions on the [Docker Compose installation page](https://docs.docker.com/compose/install/).
:::

::: details Podman
- Podman installed on your system. You can download Podman from the [official Podman website](https://podman.io/getting-started/installation).
- Podman Compose installed. You can install it using the [Podman Compose installation instructions](https://github.com/containers/podman-compose).
:::

- Sufficient system resources to run the NetApp Core Connector. Refer to the [Sizing Guide](/projects/neo/core/d-sizing.md) in the Deployment section for recommended specifications.
- ```cifs-utils``` package needs to be deployed on the Linux host.
- ```SELinux``` contexts might require adjustements based on your specific Linux host security profile.

> [!WARNING]
> The main difference between ```docker``` and ```podman``` is linked to ```podman``` requiring a ```sudo``` prefix to start as a privileged container which is not required by ```docker``` because the daemon is already running **all** containers in a privileged mode.


## Deployment Guide

Create a directory called "neo-test" in a directory of your choice to host the configuration files below.

### Environment variables
First, we need to set up the following .env file to configure the database. 

<<< @/projects/neo/examples/env 


> [!TIP]
> The usage of [Docker/Podman Secrets](https://docs.docker.com/compose/how-tos/use-secrets/) is another path to explore addressing the challenge of credentials stored locally on a hard drive.

### Compose Container file
Download the latest [```neo-containerfile.yml```](/projects/neo/examples/neo-containerfile.yml) or copy its content from:

<<< @/projects/neo/examples/neo-containerfile.yml

### Start the containers

::: code-group 

``` [Docker]
docker compose -f neo-all-in.yml up --build -d
docker ps

Expected output:
CONTAINER ID  IMAGE                                          COMMAND     CREATED        STATUS        PORTS                   NAMES
d8bbf02435fb  docker.io/library/postgres:16.10-alpine3.21    postgres    7 seconds ago  Up 8 seconds  0.0.0.0:5432->5432/tcp  neodb
1aefb8db34e8  ghcr.io/netapp/netapp-copilot-connector:3.1.1              6 seconds ago  Up 7 seconds  0.0.0.0:8081->8080/tcp  neo
792aa53a0689  ghcr.io/beezy-dev/neo-ui-framework:3.1.0                   5 seconds ago  Up 6 seconds  0.0.0.0:8080->80/tcp    neoui
670ec2f91cdf  docker.io/dockurr/samba:latest                             4 seconds ago  Up 4 seconds  0.0.0.0:445->445/tcp    neosmb

Recover logs:
docker compose -f neo-all-in.yml logs
```

``` [Podman]
sudo podman compose -f neo-all-in.yml up --build -d
sudo podman ps

Expected output:
CONTAINER ID  IMAGE                                          COMMAND     CREATED        STATUS        PORTS                   NAMES
d8bbf02435fb  docker.io/library/postgres:16.10-alpine3.21    postgres    7 seconds ago  Up 8 seconds  0.0.0.0:5432->5432/tcp  neodb
1aefb8db34e8  ghcr.io/netapp/netapp-copilot-connector:3.1.1              6 seconds ago  Up 7 seconds  0.0.0.0:8081->8080/tcp  neo
792aa53a0689  ghcr.io/beezy-dev/neo-ui-framework:3.1.0                   5 seconds ago  Up 6 seconds  0.0.0.0:8080->80/tcp    neoui
670ec2f91cdf  docker.io/dockurr/samba:latest                             4 seconds ago  Up 4 seconds  0.0.0.0:445->445/tcp    neosmb

Recover logs:
sudo podman compose -f neo-all-in.yml logs
```
::: 

You should see logs indicating that the NetApp Neo Core container has started successfully as follows:

```log
neo  | 2025-12-03 19:46:43.882 | INFO     | app.main:lifespan:146 - Starting up application...
neo  | 2025-12-03 19:46:43.882 | INFO     | app.main:lifespan:150 - 🔧 Setup mode: Skipping license validation and Graph initialization
neo  | 2025-12-03 19:46:43.882 | INFO     | app.main:lifespan:151 - 📋 Complete setup via /api/v1/setup endpoints to enable full functionality
neo  | INFO:     Application startup complete.
neo  | INFO:     Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
```


### Configure

#### via GUI
Neo Console is available at ```http://your.ip:8080``` or ```http://myhost.mydomain.tld:8080``` and will welcome you with the following screen:  

<img width="1891" height="962" alt="image" src="https://github.com/user-attachments/assets/87732882-7995-4266-83a2-3e31f59c57e8" />

Go to Settings and select the tab Neo Core to start the configuration
<img width="1891" height="962" alt="image" src="https://github.com/user-attachments/assets/2cfa73d9-33a1-4165-ab25-1628a579c6f6" />

Once a valid license key is entered and saved, the page will refresh to show the following status:
<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/5ed90473-fb88-4cbe-971f-fe305a73b98a" />

At this stage, the M365 Copilot Graph or other settings can be configured now or later. Once the desired configuration is complete, click "Setup Complete".  
This will trigger a restart of Neo's container with the configured settings:
<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/2711319d-f4f4-47d4-afa8-1b2e037289c6" />

Once Neo has restarted, the page will reload with the status "Complete", and a button "Admin Credentials" will appear to recover the temporary credentials:
<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/7db70db5-77dc-4cb9-9472-9fe912c7c0f5" />

Credentials
<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/1e063c89-e210-4c3a-9bbf-110c070b834c" />
Updating credentials
<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/0e602ddb-5d68-49f6-a0bb-1cf82539cb27" />

> [!IMPORTANT]
> This temporary password will not be accessible again once you have logged in with the credentials.
> Make sure to either save it in your password m(anager or change it in the Users page.

<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/ba62c004-d7c1-498c-8082-0af298372d7f" />

#### via API
Neo can also be configured via the API, available at ```http://your.ip:8081/docs``` or ```http://myhost.mydomain.tld:8081/docs```.

## Troubleshooting

### postgres

Check if the DB was created using both methods to verify the DB and networking at the same time:

::: code-group

```BASH [Docker]
docker exec -it neodb psql -h localhost -U postgres -l
```  

```BASH [Podman]
sudo podman exec -it neodb psql -h localhost -U postgres -l
```  
:::

or if you have ```psql``` utils deployed:  
```BASH
psql -U postgres -h 192.168.122.245 -p 5432 postgres -l
``` 

Expected output:
```                                                           
List of databases
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

Check the logs and share these with the team for any potential issues you might encounter:

::: code-group

```BASH [Docker]
docker logs -f neo
```

```BASH [Podman]
sudo podman logs -f neo
```
:::

### Neo UI 

Check the logs and share these with the team for any potential issues you might encounter:


::: code-group

```BASH [Docker]
docker logs -f neoui
```

```BASH [Podman]
sudo podman logs -f neoui
```
:::

Check the web console in the Browser for additional error messages.


### Samba (optional)

Check the logs and share these with the team for any potential issues you might encounter:

::: code-group

```BASH [Docker]
docker logs -f neosmb
```

```BASH [Podman]
sudo podman logs -f neosmb
```
:::

## Next steps
This concludes the steps to deploy the NetApp Neo Core using Docker/Podman Compose. For more advanced configurations and management options, please refer to the [Management](/projects/neo/core/management.md) section of the documentation.