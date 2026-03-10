# Prerequisites

> [!NOTE]
> NetApp Neo requires a license key to activate. Contact your NetApp representative or visit the [Innovation Labs releases](https://github.com/NetApp/Innovation-Labs/releases) page.

> [!WARNING]
> AWS ECS (Fargate) is NOT supported. This is due to the ECS containers being unable to mount shares to the container(s). If using ECS it is recommended to us AWS EC2 Instances.

## Core Requirements

- Docker / Podman / K8s: Neo is packaged as a container and must be deployed in a container environment
- Minimum: 4 vCPU / 8GB RAM (single instance). Recommended: 8+ vCPU / 16GB+ RAM for production with all services.
- Port 8000 (API), Port 8081 (Web Console)
- Database:
  - PostgreSQL Database (v17+) - can be self-hosted or managed (e.g. AWS RDS, Azure Database for PostgreSQL, etc)
  - MySQL Database (v8+) - can be self-hosted or managed (e.g. AWS RDS, Azure Database for MySQL, etc)
- ```cifs-utils``` should be install on your Linux host
- ```nfs-common``` package (required for NFS shares)

## Database Options

- **PostgreSQL**: For production deployments with high availability (Recommended)
- **MySQL**: Alternative production database option

To use PostgreSQL or MySQL, set the `DATABASE_URL` environment variable:

```bash
# PostgreSQL example
DATABASE_URL=postgresql://user:password@localhost:5432/neo

# MySQL example
DATABASE_URL=mysql://user:password@localhost:3306/neo
```

## Supported Sources

Neo can connect to the following data sources:

- SMB File Shares (CIFS / SMBv2+). This includes all NetApp ONTAP file shares and non-NetApp SMB shares (i.e. Pure Storage, Isilon, HPE, Windows File Shares, Linux Samba Shares, etc)
- NFS File Shares (v3 and v4). This includes NetApp ONTAP NFS exports and other NFS exports
- S3-Compatible Object Storage (AWS S3, NetApp StorageGRID, MinIO, etc.)

## Microsoft 365 Copilot Requirements

If you intend to connect your data to Microsoft 365 Copilot, then the following additional requirements apply:

### Network Requirements

- Port 443 open for outbound traffic to the MS Graph API
- Port 445 open for SMB file share access
- SMB File Share(s) must be routable to the connector

> [!NOTE]
> Proxy and SSL inspection firewalls are supported. See the [Configuration Guide](./d-configuration.md) for details.

### Software Requirements

- Microsoft 365 Copilot License
