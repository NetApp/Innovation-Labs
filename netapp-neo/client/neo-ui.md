
# Neo v3 for testing

This guide provides the necessary steps to deploy a "battery-included" Neo instance, using Docker or Podman, for **DEVELOPMENT and TESTING**, that includes:

- an official PostgreSQL instance, version 16.10-alpine3.21 
- version 3.1.0 of Neo 
- version 3.1.0 of Neo UI

For testing purposes, a local SAMBA service is also included. 

> [!IMPORTANT]
> This guide leverages ```podman``` as a container runtime, which calls for ```sudo``` due to its rootless nature and Neo needing rootful permissions to
> mount the shares.    
> When using ```docker```, just replace ```sudo podman``` by ```docker```.

## Deployment Guide

Create a directory called "neo-test" in your home directory or any location of your choice to host the configuration files below.

### Environment variables
First, we need to set up the following .env file to capture the database configuration. 

```INI
# NetApp Settings (Required)
DATABASE_URL=postgresql://postgres:neodbsecret@neodb:5432/neoconnectortest      # <== Needs to be changed! 
## or for MySQL:
#DATABASE_URL=mysql://user:password@localhost:3306/netapp_connector
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
    image: ghcr.io/netapp/netapp-copilot-connector:3.1.0 
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

  neoui:
    image: ghcr.io/beezy-dev/neo-ui-framework:3.1.0
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
sudo podman compose -f neo-all-in.yml up --build -d
```

Verify that all containers are started and running:
```BASH
sudo podman ps
```
Expected output:
```BASH
CONTAINER ID  IMAGE                                          COMMAND     CREATED        STATUS        PORTS                   NAMES
d8bbf02435fb  docker.io/library/postgres:16.10-alpine3.21    postgres    7 seconds ago  Up 8 seconds  0.0.0.0:5432->5432/tcp  neodb
1aefb8db34e8  ghcr.io/netapp/netapp-copilot-connector:3.1.0              6 seconds ago  Up 7 seconds  0.0.0.0:8081->8080/tcp  neo
792aa53a0689  ghcr.io/beezy-dev/neo-ui-framework:3.1.0                   5 seconds ago  Up 6 seconds  0.0.0.0:8080->80/tcp    neoui
670ec2f91cdf  docker.io/dockurr/samba:latest                             4 seconds ago  Up 4 seconds  0.0.0.0:445->445/tcp    neosmb
```

The logs can be gathered on a different console window with the following command:
```BASH
sudo podman compose -f neo-all-in.yml logs -f
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

Once Neo has restarted, the page will reload with the status "Complete" and a button "Admin Credentials" will appear to recover the temporary credentials:
<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/7db70db5-77dc-4cb9-9472-9fe912c7c0f5" />

### Admin Password
> [!IMPORTANT]
> This temporary password will not be accessible again once you have logged in with the credentials.
> Make sure to either save it in your password manager or change it in the Users page.

Credentials
<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/1e063c89-e210-4c3a-9bbf-110c070b834c" />
Updating credentials
<img width="1884" height="952" alt="image" src="https://github.com/user-attachments/assets/0e602ddb-5d68-49f6-a0bb-1cf82539cb27" />

#### via API
Neo can also be configured via the API, available at ```http://your.ip:8081/docs``` or ```http://myhost.mydomain.tld:8081/docs```.

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

