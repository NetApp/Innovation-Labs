# Multi-Protocol Data Sources

NetApp Project Neo v4 connects to your unstructured data wherever it lives. Three storage protocols are supported: **SMB** (CIFS) for Windows and Samba file shares, **NFS** for UNIX/Linux exports, and **S3** for cloud and on-premises object storage. Each protocol uses a dedicated storage backend with protocol-specific enumeration, content extraction, and ACL reading.

All protocols share a common workflow: create a share, test the connection, crawl files, extract content, and optionally run NER analysis or upload to Microsoft 365 Copilot via Graph.

## Supported Protocols at a Glance

| Protocol | Transport | Container Requirement | ACL Type | Authentication |
|----------|-----------|----------------------|----------|----------------|
| **SMB** (CIFS) | TCP 445 | Privileged or `SYS_ADMIN` | Windows NTFS ACLs | Username / password / domain |
| **NFS** (v3/v4) | TCP 2049 | Privileged or `SYS_ADMIN` | POSIX ACLs (v3) or NFSv4 rich ACLs (v4) | UNIX `sys` or Kerberos |
| **S3** | HTTPS 443 | None | S3 bucket policies / canned ACLs | Access Key ID + Secret Access Key |

---

## SMB File Shares

SMB (Server Message Block), also known as CIFS, is the standard protocol for Windows file shares. Neo mounts SMB shares read-only inside the Extractor container using `mount.cifs` and enumerates files via the local mount point. ACLs are read using `smbcacls`.

### Supported Storage Systems

- NetApp ONTAP (SMB 2.x / 3.x)
- Windows Server file shares
- Linux Samba servers
- Pure Storage FlashBlade
- Dell EMC Isilon / PowerScale
- HPE StoreEasy / Nimble

### Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `protocol` | string | Yes | Must be `"smb"` |
| `share_path` | string | Yes | UNC path: `//server/share` |
| `username` | string | Yes | SMB username |
| `password` | string | Yes | SMB password (encrypted at rest) |
| `domain` | string | No | Active Directory domain (e.g., `CORP`) |
| `smb_mount_options` | string | No | Additional mount.cifs options (comma-separated) |

### Share Path Format

The `share_path` must use the standard UNC format:

```
//server/share_name
```

Examples:
- `//fileserver01/shared-docs`
- `//192.168.1.50/finance`
- `//nas.corp.com/projects`

### ACL Extraction

Neo reads Windows NTFS ACLs using `smbcacls`. Each ACE contains:

| Component | Description | Example |
|-----------|-------------|---------|
| Principal | Domain user or group | `CORP\jdoe`, `CORP\Finance-Team` |
| Access Type | Allow or Deny | `ALLOWED`, `DENIED` |
| Flags | Inheritance flags | `OI\|CI` (object/container inherit) |
| Permissions | Access mask | `FULL`, `READ`, `CHANGE` |

Extracted principals (e.g., `CORP\jdoe`) are mapped to Entra ID (Azure AD) identities when uploading to Microsoft Graph for Copilot.

### Host Requirements

- **cifs-utils** package installed in the Extractor container image (included by default)
- Container must run in **privileged mode** or have `SYS_ADMIN` capability
- Network access to the SMB server on TCP port 445

### Example: Create an SMB Share

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "smb",
    "share_path": "//fileserver01/shared-docs",
    "username": "svc-neo",
    "password": "SecureP@ssw0rd",
    "domain": "CORP"
  }' \
  "http://localhost:8000/api/v1/shares?crawl_immediately=true"
```

### Example: SMB Share with Rules and Scheduling

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "smb",
    "share_path": "//nas.corp.com/finance",
    "username": "svc-neo",
    "password": "SecureP@ssw0rd",
    "domain": "CORP",
    "crawl_schedule": "0 2 * * 0",
    "rules": {
      "exclude_patterns": ["*.tmp", "~$*", "Thumbs.db", ".DS_Store"],
      "max_file_size": 500000000,
      "persist_file_content": true,
      "enable_copilot_upload": true,
      "enable_ner_analysis": true
    }
  }' \
  "http://localhost:8000/api/v1/shares"
```

---

## NFS File Shares

Neo connects to NFS exports by mounting them inside the Extractor container using the Linux kernel NFS client. Both NFSv3 and NFSv4 are supported, including Kerberos security flavors for secured environments. Mounts are read-only and cached across crawl cycles.

### Supported Storage Systems

- NetApp ONTAP (NFSv3 and NFSv4)
- Any NFS server exporting via NFSv3 or NFSv4
- Linux NFS servers (kernel nfsd, Ganesha)

### Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `protocol` | string | Yes | Must be `"nfs"` |
| `share_path` | string | Yes | NFS export: `server:/export/path` |
| `nfs_version` | string | No | NFS version: `"3"`, `"4"`, `"4.1"`, `"4.2"`, or `null` (auto-negotiate) |
| `nfs_security` | string | No | Security flavor: `"sys"` (default), `"krb5"`, `"krb5i"`, `"krb5p"` |
| `nfs_mount_options` | string | No | Additional mount options (comma-separated) |
| `username` | string | No | Kerberos principal (e.g., `svc-neo@CORP.COM`) for krb5 flavors |
| `password` | string | No | Kerberos password for ticket acquisition |

### Share Path Format

```
server:/export/path
```

Examples:
- `nas01:/vol/data`
- `192.168.1.100:/exports/shared`
- `fileserver.corp.com:/mnt/projects`

### NFS Version Selection

| Value | Description |
|-------|-------------|
| `null` (default) | Kernel auto-negotiates the highest supported version |
| `"3"` | Force NFSv3 -- uses portmapper (TCP 111 + 2049), POSIX ACLs |
| `"4"` | Force NFSv4 -- single port (TCP 2049), rich ACLs |
| `"4.1"` | Force NFSv4.1 -- adds session trunking |
| `"4.2"` | Force NFSv4.2 -- adds server-side copy and sparse file support |

### Security Flavors

| Value | Description | Credentials Required |
|-------|-------------|---------------------|
| `"sys"` (default) | Standard UNIX authentication (UID/GID) | No |
| `"krb5"` | Kerberos authentication | Yes |
| `"krb5i"` | Kerberos with integrity checking | Yes |
| `"krb5p"` | Kerberos with privacy (full encryption) | Yes |

### Default Mount Options

Neo always applies these mount options:

| Option | Purpose |
|--------|---------|
| `ro` | Read-only mount -- Neo never modifies source files |
| `noatime` | Skip access time updates to reduce NFS traffic |
| `nolock` | Disable NFS file locking (not available in containers) |

Any options specified in `nfs_mount_options` are appended to these defaults. Useful additions include `soft`, `intr`, `timeo=N`, and `retrans=N`.

### ACL Support

Neo reads file ACLs from NFS exports to support permission-aware search and Microsoft Graph upload.

**NFSv4 ACLs** are read using `nfs4_getfacl`. Each ACE contains:

| Component | Description | Example |
|-----------|-------------|---------|
| Type | Allow or Deny | `A` (allow), `D` (deny) |
| Flags | Inheritance and group flags | `g` (group), `d` (directory inherit) |
| Principal | User or group identity | `jdoe@CORP.COM`, `ADMINS@CORP.COM` |
| Permissions | NFSv4 access mask | `rxtncy` |

**NFSv3 POSIX ACLs** are read using `getfacl`. These include:

- Owner and owner permissions
- Group and group permissions
- Named user and group ACEs (e.g., `user:jdoe:r-x`)
- Other permissions

Neo tries `nfs4_getfacl` first and falls back to `getfacl` automatically. If neither returns ACL data, share-level ACL override rules apply.

### Host Requirements

- **nfs-common** and **nfs4-acl-tools** packages installed in the Extractor container image (included by default)
- Container must run in **privileged mode** (or `SYS_ADMIN` capability with `apparmor=unconfined`)
- Network access to the NFS server on TCP 2049 (and TCP/UDP 111 for NFSv3)
- NFS server must export with the `insecure` option when Docker NAT is involved

### Example: Basic NFS Share

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "nfs",
    "share_path": "nas01:/exports/data"
  }' \
  "http://localhost:8000/api/v1/shares?crawl_immediately=true"
```

### Example: NFSv4 with Kerberos Integrity

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "nfs",
    "share_path": "secure-nas.corp.com:/secure/finance",
    "nfs_version": "4",
    "nfs_security": "krb5i",
    "username": "svc-neo@CORP.COM",
    "password": "kerberos-password"
  }' \
  "http://localhost:8000/api/v1/shares"
```

### Example: NFS with Custom Mount Options and Rules

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "nfs",
    "share_path": "nas01:/vol/projects",
    "nfs_version": "4",
    "nfs_security": "sys",
    "nfs_mount_options": "soft,intr,timeo=30,retrans=2",
    "crawl_schedule": "0 2 * * 0",
    "rules": {
      "exclude_patterns": ["*.tmp", "*.lock", "~$*", ".DS_Store"],
      "max_file_size": 500000000,
      "modified_within_days": 180,
      "persist_file_content": true,
      "enable_ner_analysis": true
    }
  }' \
  "http://localhost:8000/api/v1/shares?crawl_immediately=true"
```

---

## S3-Compatible Object Storage

Neo connects to S3 buckets using the `boto3` library over HTTPS. Unlike SMB and NFS, S3 does not require filesystem mounting -- objects are accessed directly via the S3 API. Files are downloaded to a temporary directory during content extraction and cleaned up automatically.

### Supported Storage Systems

- AWS S3
- NetApp StorageGRID
- MinIO
- Any S3-compatible object store

### Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `protocol` | string | Yes | Must be `"s3"` |
| `share_path` | string | Yes | S3 URI: `s3://bucket` or `s3://bucket/prefix` |
| `username` | string | Yes | AWS Access Key ID |
| `password` | string | Yes | AWS Secret Access Key (encrypted at rest) |
| `s3_endpoint_url` | string | No | Custom endpoint URL (for StorageGRID, MinIO, etc.) |
| `s3_region` | string | No | AWS region (e.g., `us-east-1`) |
| `s3_bucket` | string | No | Explicit bucket name (auto-parsed from `share_path` if not set) |
| `s3_prefix` | string | No | Object key prefix filter (auto-parsed from `share_path` if not set) |
| `s3_use_ssl` | boolean | No | Use HTTPS for connections (default: `true`) |

### Share Path Format

```
s3://bucket-name
s3://bucket-name/prefix
```

Examples:
- `s3://company-documents` -- crawl the entire bucket
- `s3://company-documents/reports/2026` -- only crawl objects under the `reports/2026/` prefix
- `s3://data-lake/team-a/reports` -- crawl a specific subfolder

### ACL Behavior

S3 has limited native ACL support compared to SMB and NFS. Neo reads S3 object ACLs and bucket policies when available, but S3 ACLs identify principals by AWS account IDs and canonical user IDs -- these do not map directly to Entra ID users.

For Microsoft Graph / Copilot integration, configure **ACL override rules** at the share level:

**Grant access to everyone in the tenant:**
```json
{
  "rules": {
    "acl_override_mode": "everyone"
  }
}
```

**Grant access to specific users or groups:**
```json
{
  "rules": {
    "acl_override_mode": "specified",
    "acl_override_principals": [
      "finance-team@corp.com",
      "john.doe@corp.com"
    ]
  }
}
```

If no ACL override is configured and `ACL_STRICT_MODE=true` (the default), files without resolvable ACLs are skipped during Graph upload to prevent accidental data exposure.

### Streaming Support

The S3 backend supports streaming extraction via `get_stream()`. Content can be read directly from the S3 response body as a `BytesIO` stream, avoiding the need to write a temporary file to disk for supported extractors.

For extractors that require a filesystem path, objects are downloaded to a deterministic temporary path under `/tmp/s3_extract/` and cleaned up automatically.

### Host Requirements

- **No special container privileges required** -- S3 access is purely API-based
- `boto3` Python package installed (included in the default image)
- Network access to the S3 endpoint over HTTPS (port 443, or custom port for StorageGRID/MinIO)

### Required S3 Permissions

| Permission | Purpose |
|-----------|---------|
| `s3:ListBucket` | Enumerate objects in the bucket |
| `s3:GetObject` | Download objects for content extraction |
| `s3:GetBucketAcl` | Read bucket-level ACLs (optional) |
| `s3:GetObjectAcl` | Read object-level ACLs (optional) |

### Example: AWS S3 Bucket

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "s3",
    "share_path": "s3://company-documents",
    "username": "AKIAIOSFODNN7EXAMPLE",
    "password": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "s3_region": "us-east-1"
  }' \
  "http://localhost:8000/api/v1/shares?crawl_immediately=true"
```

### Example: NetApp StorageGRID

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "s3",
    "share_path": "s3://grid-archive/legal",
    "username": "GRIDACCESSKEY",
    "password": "GRIDSECRETKEY",
    "s3_endpoint_url": "https://s3.storagegrid.company.com:8082",
    "s3_region": "us-east-1",
    "s3_use_ssl": true
  }' \
  "http://localhost:8000/api/v1/shares?crawl_immediately=true"
```

### Example: MinIO

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "s3",
    "share_path": "s3://test-bucket",
    "username": "minioadmin",
    "password": "minioadmin",
    "s3_endpoint_url": "http://minio.local:9000",
    "s3_region": "us-east-1",
    "s3_use_ssl": false
  }' \
  "http://localhost:8000/api/v1/shares?crawl_immediately=true"
```

### Example: S3 with Full Rules and Scheduling

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "s3",
    "share_path": "s3://prod-data-lake/customer-docs",
    "username": "AKIAIOSFODNN7EXAMPLE",
    "password": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "s3_region": "eu-west-1",
    "crawl_schedule": "0 1 * * 0",
    "rules": {
      "exclude_patterns": ["*.tmp", "*.bak", "*.cache"],
      "include_patterns": ["*.pdf", "*.docx", "*.xlsx", "*.pptx"],
      "max_file_size": 500000000,
      "modified_within_days": 90,
      "persist_file_content": true,
      "enable_copilot_upload": true,
      "enable_ner_analysis": true,
      "acl_override_mode": "specified",
      "acl_override_principals": ["data-analysts@company.com", "legal-team@company.com"]
    }
  }' \
  "http://localhost:8000/api/v1/shares"
```

---

## Protocol Comparison

| Feature | SMB | NFS | S3 |
|---------|-----|-----|-----|
| **Transport** | TCP 445 | TCP 2049 (+ TCP/UDP 111 for v3) | HTTPS 443 |
| **Connection method** | Filesystem mount (`mount.cifs`) | Filesystem mount (`mount -t nfs`) | API calls (`boto3`) |
| **Container privileges** | Privileged / `SYS_ADMIN` | Privileged / `SYS_ADMIN` | None required |
| **Authentication** | Username + password + domain | UNIX `sys` or Kerberos | Access Key + Secret Key |
| **ACL type** | Windows NTFS ACLs | POSIX ACLs (v3) / NFSv4 rich ACLs (v4) | Bucket policies + canned ACLs |
| **ACL granularity** | Per-file, per-principal | Per-file, per-principal | Per-bucket or per-object (limited) |
| **Entra ID mapping** | Direct (`DOMAIN\user` to UPN) | NFSv4 principals (`user@DOMAIN`) | Requires ACL override rules |
| **File access** | Direct read from mount | Direct read from mount | Download to temp file or stream |
| **Streaming extraction** | No | No | Yes (`get_stream()`) |
| **Pagination** | Offset-based | Offset-based | S3 continuation tokens |
| **Scalability** | Millions of files | Millions of files | Unlimited (paginated listing) |
| **Kerberos support** | Via domain join | `krb5`, `krb5i`, `krb5p` | N/A |
| **Read-only access** | Mounted `ro` | Mounted `ro,noatime,nolock` | Read-only API calls |
| **Mount caching** | TTL-based via MountManager | Hash-based, reused across crawls | N/A (no mount) |

---

## Choosing a Protocol

### Use SMB when:

- Your data lives on **Windows file servers**, **NetApp ONTAP CIFS shares**, or **Samba**
- You need **Windows NTFS ACLs** mapped to Entra ID for Microsoft 365 Copilot
- Your organization uses **Active Directory** for identity
- Files are accessed via UNC paths (`\\server\share`)

### Use NFS when:

- Your data lives on **Linux/UNIX NFS exports** or **NetApp ONTAP NFS volumes**
- You need **POSIX ACLs** (v3) or **NFSv4 rich ACLs** for permission-aware search
- You want **simpler firewall rules** (NFSv4 uses a single port: TCP 2049)
- Your environment uses **Kerberos** for authentication (`krb5`, `krb5i`, `krb5p`)

### Use S3 when:

- Your data lives in **AWS S3**, **NetApp StorageGRID**, **MinIO**, or another S3-compatible store
- You do **not need file-level ACLs** (or are comfortable with share-level ACL overrides)
- You want the **simplest container setup** (no privileged mode required)
- Your data is already organized in **buckets and prefixes**
- You need to crawl **very large datasets** with efficient paginated enumeration

### Mixing Protocols

Neo supports adding shares of different protocols simultaneously. A single Neo deployment can crawl SMB shares from Windows file servers, NFS exports from NetApp ONTAP, and S3 buckets from StorageGRID -- all indexing into the same PostgreSQL database and searchable through the same API.

---

## Testing Connections

All protocols support connection testing, both during share creation and on demand:

```bash
# Test during creation (automatic)
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"protocol": "smb", "share_path": "//server/share", "username": "user", "password": "pass"}' \
  "http://localhost:8000/api/v1/shares"

# Manual test on an existing share
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/shares/{share_id}/test-connection"
```

Connection test responses include the protocol, method used, and metadata about the connection:

| Protocol | Test Method | What It Validates |
|----------|-------------|-------------------|
| SMB | `mount` | Mount succeeds, share directory is listable |
| NFS | `nfs_mount` | Mount succeeds, export directory is listable |
| S3 | `s3_list_objects` | Credentials valid, bucket accessible, prefix listable |
