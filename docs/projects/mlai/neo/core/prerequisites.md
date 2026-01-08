# Prerequisites

> [!WARNING] Important
> - NetApp Neo for M365 Copilot is currently in **Private Preview** . This means that the connector is not yet fully supported and may have some limitations. The connector requires a license to activate. You can request access to the connector by joining the Early Access Program (EAP). Please book a meeting with the following link to join the EAP: [Book a meeting with NetApp](https://outlook.office.com/bookwithme/user/d636d7a02ad8477c9af9a0cbb029af4d@netapp.com/meetingtype/nm-mXkp-TUO1CdzOmFfIBw2?anonymous&ismsaljsauthenabled&ep=mlink)
> - AWS ECS (Fargate) is NOT supported. This is due to the ECS containers being unable to mount shares to the container(s). If using ECS it is recommended to us AWS EC2 Instances.

## Core Requirements

- Docker / Podman / K8s: Neo is packaged as a container and must be deployed in a container environment
- 4 vCPU / 8GB RAM
- Port 8080 (by default) for the web management interface
- Database:
  - PostgreSQL Database (v16+) - can be self-hosted or managed (e.g. AWS RDS, Azure Database for PostgreSQL, etc)
  - MySQL Database (v8+) - can be self-hosted or managed (e.g. AWS RDS, Azure Database for MySQL, etc)
- ```cifs-utils``` should be install on your Linux host

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

Future support (coming soon):

- NFS File Shares (v3+)
- S3 Buckets (AWS S3, NetApp StorageGRID, etc)

## Microsoft 365 Copilot Requirements

If you intend to connect your data to Microsoft 365 Copilot, then the following additional requirements apply:

### Network Requirements

- Port 443 open for outbound traffic to the MS Graph API
- Port 445 open for SMB file share access
- SMB File Share(s) must be routable to the connector

> [!NOTE]
> Proxys and SSL Inspection Firewalls are not officially supported although experimental support is available in 3.0.5+

### Software Requirements

- Microsoft 365 Copilot License