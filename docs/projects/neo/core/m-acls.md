# Item Level Permissions (ACLs)

This guide explains how to configure per-share ACL overrides to bypass file-level ACL resolution when uploading files to Microsoft Graph.

## Overview

By default, the NetApp Connector extracts Access Control Lists (ACLs) from each file on SMB shares and resolves them to Microsoft Entra users and groups. This ensures that files uploaded to Microsoft Graph maintain the same access permissions as the original files.

However, there are scenarios where file-level ACL resolution is not possible or desirable:

- **No AD-to-Entra sync**: The file server uses local Active Directory accounts that are not synchronized to Microsoft Entra
- **Legacy file servers**: Older file servers with non-standard ACL configurations
- **Public shares**: Shares where all content should be accessible to everyone in the organization
- **Simplified permissions**: When you want to apply uniform permissions across all files in a share

For these scenarios, you can configure **per-share ACL overrides** that bypass file-level ACL resolution entirely.

## ACL Override Modes

| Mode        | Description                                              |
| ----------- | -------------------------------------------------------- |
| `everyone`  | Grant access to all users in the Microsoft Entra tenant  |
| `specified` | Grant access only to specified Entra users and/or groups |

When no ACL override is configured, the default behavior (file-level ACL resolution) is used.

## Configuration

ACL overrides are configured in the share's `rules` object when creating or updating a share.

### Option 1: Grant Access to Everyone

Use this when all files in the share should be accessible to everyone in your organization.

```json
POST /shares
{
  "share_path": "\\\\fileserver\\public-documents",
  "username": "domain\\serviceaccount",
  "password": "your-password",
  "crawl_schedule": "0 2 * * *",
  "rules": {
    "acl_override_mode": "everyone"
  }
}
```

**Result**: All files from this share will be uploaded to Microsoft Graph with permissions that allow any user in your Entra tenant to access them.

### Option 2: Grant Access to Specific Users/Groups

Use this when files should only be accessible to specific Entra users or groups.

```json
POST /shares
{
  "share_path": "\\\\fileserver\\department-files",
  "username": "domain\\serviceaccount",
  "password": "your-password",
  "crawl_schedule": "0 2 * * *",
  "rules": {
    "acl_override_mode": "specified",
    "acl_override_principals": [
      {
        "type": "group",
        "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
      },
      {
        "type": "user",
        "id": "12345678-90ab-cdef-1234-567890abcdef"
      }
    ]
  }
}
```

**Result**: All files from this share will be uploaded to Microsoft Graph with permissions that only allow the specified users and groups to access them.

## Finding Entra Object IDs

The `acl_override_principals` list requires Entra Object IDs (GUIDs), not display names. Here's how to find them:

### Using Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** (formerly Azure Active Directory)
3. For users: Go to **Users** → Select the user → Copy the **Object ID**
4. For groups: Go to **Groups** → Select the group → Copy the **Object ID**

### Using Microsoft Graph Explorer

1. Go to [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)
2. Sign in with your admin account
3. For users: Run `GET https://graph.microsoft.com/v1.0/users?$filter=displayName eq 'User Name'`
4. For groups: Run `GET https://graph.microsoft.com/v1.0/groups?$filter=displayName eq 'Group Name'`
5. Copy the `id` field from the response

### Using PowerShell

```powershell
# Install Microsoft Graph PowerShell module if needed
Install-Module Microsoft.Graph -Scope CurrentUser

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All"

# Find a user by display name
Get-MgUser -Filter "displayName eq 'John Doe'" | Select-Object Id, DisplayName

# Find a group by display name
Get-MgGroup -Filter "displayName eq 'Marketing Team'" | Select-Object Id, DisplayName
```

## Updating Existing Shares

You can add or modify ACL overrides on existing shares using the PATCH endpoint:

### Add ACL Override to Existing Share

```json
PATCH /shares/{share_id}
{
  "rules": {
    "acl_override_mode": "everyone"
  }
}
```

### Change from Everyone to Specified Principals

```json
PATCH /shares/{share_id}
{
  "rules": {
    "acl_override_mode": "specified",
    "acl_override_principals": [
      {"type": "group", "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"}
    ]
  }
}
```

### Remove ACL Override (Return to File-Level Resolution)

```json
PATCH /shares/{share_id}
{
  "rules": {
    "acl_override_mode": null
  }
}
```

<blockquote style="background-color: #e7f3ff; border-left: 4px solid #2196F3; padding: 10px; margin: 10px 0;">
<strong>📘 Note:</strong> After changing ACL settings, you may want to trigger a re-crawl to update permissions on existing files:
<pre><code>POST /shares/{share_id}/crawl
</code></pre>
</blockquote>

## Combining with Other Rules

ACL overrides can be combined with other share rules:

```json
{
  "share_path": "\\\\fileserver\\documents",
  "username": "domain\\serviceaccount",
  "password": "your-password",
  "rules": {
    "acl_override_mode": "specified",
    "acl_override_principals": [
      { "type": "group", "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890" }
    ],
    "include_patterns": ["*.pdf", "*.docx", "*.xlsx"],
    "max_file_size": 104857600,
    "modified_within_days": 365
  }
}
```

This configuration:

- Grants access only to the specified group
- Only processes PDF, Word, and Excel files
- Limits file size to 100MB
- Only includes files modified in the last year

## Validation Rules

The connector validates ACL override configurations:

| Validation             | Error Message                                                                                    |
| ---------------------- | ------------------------------------------------------------------------------------------------ |
| Invalid mode           | `Invalid acl_override_mode 'xyz'. Must be one of: everyone, specified`                           |
| Missing principals     | `acl_override_principals must contain at least one principal when acl_override_mode='specified'` |
| Invalid principal type | `acl_override_principals[0] 'type' must be 'user' or 'group'`                                    |
| Missing principal ID   | `acl_override_principals[0] missing required 'id' field`                                         |

## Monitoring

Check application logs for ACL override activity:

```
# ACL override in use
"Using share-level ACL override (everyone) for /path/to/file.pdf"
"Using share-level ACL override (specified principals) for /path/to/file.docx"

# File-level ACL resolution (default behavior)
"Resolving ACLs for /path/to/file.pdf using cached resolution"
```

## Security Considerations

<blockquote style="background-color: #ffe6e6; border-left: 4px solid #f44336; padding: 10px; margin: 10px 0;">
<strong>❗ Important:</strong> ACL overrides bypass the original file permissions. Consider the following:
<ol>
<li><strong>Data Exposure Risk</strong>: Using <code>acl_override_mode: "everyone"</code> makes all files in the share accessible to everyone in your Entra tenant. Only use this for truly public content.</li>
<li><strong>Audit Trail</strong>: The original file ACLs are still extracted and stored in the database for auditing purposes, even when overrides are applied.</li>
<li><strong>Principle of Least Privilege</strong>: When using <code>specified</code> mode, grant access only to the users and groups that genuinely need it.</li>
<li><strong>Regular Review</strong>: Periodically review shares with ACL overrides to ensure the permissions are still appropriate.</li>
</ol>
</blockquote>

## Comparison: ACL Override vs ACL_STRICT_MODE

| Feature       | ACL Override                     | ACL_STRICT_MODE                                       |
| ------------- | -------------------------------- | ----------------------------------------------------- |
| Scope         | Per-share                        | Global (all shares)                                   |
| Purpose       | Bypass file-level ACL resolution | Control fallback behavior when ACLs can't be resolved |
| Configuration | Share rules                      | Environment variable                                  |
| Precedence    | Takes priority                   | Only applies when no ACL override is set              |

When `acl_override_mode` is set on a share, the global `ACL_STRICT_MODE` setting is ignored for that share.

## Troubleshooting

### Files Not Appearing in Search Results

1. Verify the share has been crawled: `GET /shares/{share_id}`
2. Check the share status is `ready`
3. Verify the ACL override configuration is correct
4. Check logs for any upload errors

### Permission Denied Errors

1. Ensure the Entra Object IDs are correct
2. Verify the users/groups exist in your Entra tenant
3. Check that the Microsoft Graph connector has appropriate permissions

### ACL Override Not Taking Effect

1. Confirm the share rules were saved: `GET /shares/{share_id}` and check the `rules` field
2. Trigger a re-crawl: `POST /shares/{share_id}/crawl`
3. Check logs for "Using share-level ACL override" messages