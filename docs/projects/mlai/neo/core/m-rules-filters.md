# Rules and Filters

This guide explains how to configure share rules to control which files are processed, how they are filtered, and what happens after processing.

## Overview

Share rules allow you to customize file processing behavior on a per-share basis. Rules are configured in the `rules` object when creating or updating a share via the API.

**Key capabilities:**

- **File pattern filtering** - Include or exclude files based on filename patterns
- **Size filtering** - Process only files within specified size ranges
- **Date filtering** - Filter files by creation, modification, or access dates
- **Rolling date windows** - Dynamic date filters that update automatically
- **Content persistence** - Control whether file content is retained after upload
- **Upload control** - Enable or disable Microsoft Graph/Copilot integration
- **ACL overrides** - Bypass file-level permissions (see [ACL Override Guide](./management-acls.md)
- **NER analysis** - Enable entity extraction (see [NER Feature Guide - COMING SOON](./management-rules-filters.md))

## Quick Start

### Basic Share with Default Rules

```json
POST /shares
{
  "share_path": "\\\\server\\share",
  "username": "domain\\user",
  "password": "password",
  "realm": "DOMAIN.COM",
  "use_kerberos": "required"
}
```

Default rules are applied automatically:

- All files included (no pattern filtering)
- Max file size: 1GB
- Min file size: 0 bytes
- Content persisted after upload
- Microsoft Graph upload enabled

### Share with Custom Rules

```json
POST /shares
{
  "share_path": "\\\\server\\documents",
  "username": "domain\\user",
  "password": "password",
  "realm": "DOMAIN.COM",
  "use_kerberos": "required",
  "rules": {
    "include_patterns": ["*.pdf", "*.docx", "*.xlsx"],
    "max_file_size": 104857600,
    "modified_within_days": 90,
    "persist_file_content": false
  }
}
```

---

## Pattern Filtering

Pattern filtering allows you to control which files are processed based on their filenames and paths.

### Include Patterns

Use `include_patterns` to specify which files **should be processed**. All other files are ignored.

```json
{
  "rules": {
    "include_patterns": ["*.pdf", "*.docx", "*.xlsx", "*.pptx"]
  }
}
```

**Pattern syntax:**
| Pattern | Matches |
|---------|---------|
| `*.pdf` | All PDF files |
| `*.doc*` | Files ending in .doc, .docx, .docm, etc. |
| `report_*` | Files starting with "report\_" |
| `**/reports/**` | Any file in a "reports" directory at any depth |
| `**/2024/*.pdf` | PDF files in any "2024" directory |

**Examples:**

```json
// Only process Office documents
{
  "rules": {
    "include_patterns": ["*.pdf", "*.docx", "*.xlsx", "*.pptx"]
  }
}

// Only process files in specific directories
{
  "rules": {
    "include_patterns": ["**/contracts/**", "**/invoices/**", "**/reports/**"]
  }
}

// Combine file types and paths
{
  "rules": {
    "include_patterns": ["**/legal/*.pdf", "**/finance/*.xlsx", "*.docx"]
  }
}
```

### Exclude Patterns

Use `exclude_patterns` to specify which files **should be ignored**. All other files are processed.

```json
{
  "rules": {
    "exclude_patterns": ["*.tmp", "*.bak", "~$*", ".git/*"]
  }
}
```

**Common exclusion patterns:**

| Pattern                  | Purpose                     |
| ------------------------ | --------------------------- |
| `*.tmp`, `*.bak`         | Temporary and backup files  |
| `~$*`                    | Office temporary files      |
| `.git/*`, `.svn/*`       | Version control directories |
| `**/node_modules/**`     | Node.js dependencies        |
| `**/cache/**`            | Cache directories           |
| `Thumbs.db`, `.DS_Store` | System files                |

**Examples:**

```json
// Exclude temporary and system files
{
  "rules": {
    "exclude_patterns": ["*.tmp", "*.bak", "~$*", "Thumbs.db", ".DS_Store"]
  }
}

// Exclude specific directories
{
  "rules": {
    "exclude_patterns": ["**/archive/**", "**/backup/**", "**/temp/**"]
  }
}
```

### Important: Mutual Exclusivity

> [!WARNING]
> You cannot use both ```include_patterns``` and ```exclude_patterns``` in the same share.

Choose one approach:

- Use `include_patterns` when you want to process only specific file types
- Use `exclude_patterns` when you want to process most files but skip certain ones

```json
// ❌ INVALID - will return an error
{
  "rules": {
    "include_patterns": ["*.pdf"],
    "exclude_patterns": ["*.tmp"]
  }
}

// ✅ VALID - use include patterns only
{
  "rules": {
    "include_patterns": ["*.pdf"]
  }
}
```

### Pattern Matching Behavior

- **Case insensitive**: `*.PDF` and `*.pdf` match the same files
- **Path separators**: Use `**` for recursive matching across directories
- **Wildcards**: `*` matches any characters, `?` matches single character

---

## Size Filtering

Control which files are processed based on their size.

### Maximum File Size

```json
{
  "rules": {
    "max_file_size": 104857600
  }
}
```

Files larger than this size (in bytes) are skipped.

**Common size values:**

| Size   | Bytes                |
| ------ | -------------------- |
| 1 MB   | 1048576              |
| 10 MB  | 10485760             |
| 50 MB  | 52428800             |
| 100 MB | 104857600            |
| 500 MB | 524288000            |
| 1 GB   | 1073741824 (default) |

### Minimum File Size

```json
{
  "rules": {
    "min_file_size": 1024
  }
}
```

Files smaller than this size (in bytes) are skipped. Useful for excluding empty or near-empty files.

### Combined Size Filtering

```json
{
  "rules": {
    "min_file_size": 1024,
    "max_file_size": 52428800
  }
}
```

This processes only files between 1 KB and 50 MB.

---

## Date Filtering

Filter files based on their timestamps. Two approaches are available:

1. **Static dates** - Fixed date/time boundaries
2. **Rolling windows** - Dynamic windows that update automatically

### Static Date Filters

Use ISO8601 datetime format for precise date boundaries.

```json
{
  "rules": {
    "created_at_min": "2024-01-01T00:00:00Z",
    "created_at_max": "2024-12-31T23:59:59Z",
    "modified_time_min": "2024-06-01T00:00:00Z",
    "modified_time_max": "2024-12-31T23:59:59Z",
    "accessed_at_min": "2024-01-01T00:00:00Z",
    "accessed_at_max": "2024-12-31T23:59:59Z"
  }
}
```

**Available static filters:**

| Filter              | Description                                |
| ------------------- | ------------------------------------------ |
| `created_at_min`    | Only files created at or after this date   |
| `created_at_max`    | Only files created before or at this date  |
| `modified_time_min` | Only files modified at or after this date  |
| `modified_time_max` | Only files modified before or at this date |
| `accessed_at_min`   | Only files accessed at or after this date  |
| `accessed_at_max`   | Only files accessed before or at this date |

### Rolling Window Filters

Rolling windows automatically update based on the current date, making them ideal for ongoing synchronization.

```json
{
  "rules": {
    "modified_within_days": 30
  }
}
```

This processes only files modified in the last 30 days. The window moves forward automatically with each crawl.

**Available rolling filters:**

| Filter                   | Description                             |
| ------------------------ | --------------------------------------- |
| `created_within_days`    | Files created within the last N days    |
| `created_within_months`  | Files created within the last N months  |
| `created_within_years`   | Files created within the last N years   |
| `modified_within_days`   | Files modified within the last N days   |
| `modified_within_months` | Files modified within the last N months |
| `modified_within_years`  | Files modified within the last N years  |
| `accessed_within_days`   | Files accessed within the last N days   |
| `accessed_within_months` | Files accessed within the last N months |
| `accessed_within_years`  | Files accessed within the last N years  |

**Examples:**

```json
// Process files modified in the last 90 days
{
  "rules": {
    "modified_within_days": 90
  }
}

// Process files created in the last 2 years
{
  "rules": {
    "created_within_years": 2
  }
}

// Process recently accessed files (last 6 months)
{
  "rules": {
    "accessed_within_months": 6
  }
}
```

### Important: Static vs Rolling

> [!WARNING]
> You cannot combine static dates and rolling windows for the same timestamp type.

```json
// ❌ INVALID - mixing static and rolling for modified_time
{
  "rules": {
    "modified_time_min": "2024-01-01T00:00:00Z",
    "modified_within_days": 30
  }
}

// ✅ VALID - use one approach per timestamp type
{
  "rules": {
    "modified_within_days": 30,
    "created_at_min": "2024-01-01T00:00:00Z"
  }
}
```

---

## Content Persistence

Control whether extracted file content is retained in the database after successful upload to Microsoft Graph.

### persist_file_content

```json
{
  "rules": {
    "persist_file_content": true
  }
}
```

| Value            | Behavior                                                  |
| ---------------- | --------------------------------------------------------- |
| `true` (default) | Keep extracted content in database after Graph upload     |
| `false`          | Clear content from database after successful Graph upload |

**Use cases for `false`:**

- Reduce database storage requirements
- Comply with data retention policies
- Minimize data exposure risk

> [!NOTE]
> The ```PERSIST_FILE_CONTENT_OVERRIDE``` environment variable can override this setting at the deployment level for security purposes.


## Upload Control

Control whether files are uploaded to Microsoft Graph/Copilot.

### enable_copilot_upload

```json
{
  "rules": {
    "enable_copilot_upload": true
  }
}
```

| Value            | Behavior                                                |
| ---------------- | ------------------------------------------------------- |
| `true` (default) | Upload files to Microsoft Graph for Copilot integration |
| `false`          | Store files in local database only, no Graph upload     |

**Use cases for `false`:**

- Local-only deployments without Microsoft 365
- Testing and development environments
- Customers who want direct database access without Copilot

---

## Complete Rules Reference

### All Available Rules

```json
{
  "rules": {
    // Pattern filtering (mutually exclusive)
    "exclude_patterns": ["*.tmp", "*.bak"],
    "include_patterns": ["*.pdf", "*.docx"],

    // Size filtering
    "max_file_size": 1073741824,
    "min_file_size": 0,

    // Static date filters
    "created_at_min": "2024-01-01T00:00:00Z",
    "created_at_max": "2024-12-31T23:59:59Z",
    "modified_time_min": "2024-01-01T00:00:00Z",
    "modified_time_max": "2024-12-31T23:59:59Z",
    "accessed_at_min": "2024-01-01T00:00:00Z",
    "accessed_at_max": "2024-12-31T23:59:59Z",

    // Rolling date filters
    "created_within_days": 30,
    "created_within_months": 6,
    "created_within_years": 2,
    "modified_within_days": 30,
    "modified_within_months": 6,
    "modified_within_years": 2,
    "accessed_within_days": 30,
    "accessed_within_months": 6,
    "accessed_within_years": 2,

    // Content and upload control
    "persist_file_content": true,
    "enable_copilot_upload": true,

    // ACL overrides (see acl-override-guide)
    "acl_override_mode": "everyone",
    "acl_override_principals": [],

    // NER analysis (see ner-feature-guide)
    "enable_ner_analysis": false,
    "ner_schema": "default",
    "ner_entity_types": ["person", "organization", "location"],
    "ner_classifications": {},
    "ner_structured_extraction": {},
    "ner_confidence_threshold": 0.7
  }
}
```

### Default Values

| Rule                         | Default Value                |
| ---------------------------- | ---------------------------- |
| `exclude_patterns`           | `[]` (empty)                 |
| `include_patterns`           | `[]` (empty)                 |
| `max_file_size`              | `1073741824` (1 GB)          |
| `min_file_size`              | `0`                          |
| `created_at_min/max`         | `null` (no filter)           |
| `modified_time_min/max`      | `null` (no filter)           |
| `accessed_at_min/max`        | `null` (no filter)           |
| `*_within_days/months/years` | `null` (no filter)           |
| `persist_file_content`       | `true`                       |
| `enable_copilot_upload`      | `true`                       |
| `acl_override_mode`          | `null` (use file-level ACLs) |
| `enable_ner_analysis`        | `false`                      |

---

## Updating Rules

Use the PATCH endpoint to update rules on existing shares.

### Add or Modify Rules

```json
PATCH /shares/{share_id}
{
  "rules": {
    "include_patterns": ["*.pdf", "*.docx"],
    "modified_within_days": 60
  }
}
```

### Remove a Rule

Set the rule to its default value or `null`:

```json
PATCH /shares/{share_id}
{
  "rules": {
    "include_patterns": [],
    "modified_within_days": null
  }
}
```

### Trigger Re-crawl After Rule Changes

After changing rules, trigger a re-crawl to apply the new filters:

```bash
POST /shares/{share_id}/crawl
```

---

## Common Configurations

### Office Documents Only

```json
{
  "rules": {
    "include_patterns": [
      "*.pdf",
      "*.doc",
      "*.docx",
      "*.xls",
      "*.xlsx",
      "*.ppt",
      "*.pptx"
    ],
    "max_file_size": 104857600
  }
}
```

### Recent Files with Storage Optimization

```json
{
  "rules": {
    "modified_within_months": 6,
    "max_file_size": 52428800,
    "persist_file_content": false
  }
}
```

### Development/Test Environment

```json
{
  "rules": {
    "include_patterns": ["*.pdf"],
    "max_file_size": 10485760,
    "enable_copilot_upload": false
  }
}
```

### Legal/Compliance Documents

```json
{
  "rules": {
    "include_patterns": ["**/contracts/**", "**/legal/**", "**/compliance/**"],
    "exclude_patterns": [],
    "created_within_years": 7,
    "persist_file_content": true
  }
}
```

### Exclude Temporary and System Files

```json
{
  "rules": {
    "exclude_patterns": [
      "*.tmp",
      "*.bak",
      "*.swp",
      "~$*",
      "Thumbs.db",
      ".DS_Store",
      "desktop.ini",
      "**/node_modules/**",
      "**/.git/**",
      "**/cache/**"
    ]
  }
}
```

---

## Troubleshooting

### Files Not Being Processed

1. **Check pattern matching**: Verify your patterns match the expected files
2. **Check size limits**: Ensure files are within min/max size range
3. **Check date filters**: Verify files fall within date boundaries
4. **View share rules**: `GET /shares/{share_id}` to confirm rules are saved

### Too Many Files Being Processed

1. **Add include patterns**: Narrow down to specific file types
2. **Add date filters**: Limit to recent files
3. **Reduce max size**: Skip large files

### Rules Not Taking Effect

1. **Verify rules saved**: `GET /shares/{share_id}` and check `rules` field
2. **Trigger re-crawl**: `POST /shares/{share_id}/crawl`
3. **Check logs**: Look for filtering messages in application logs

### Validation Errors

| Error                                                       | Cause                          | Solution                                    |
| ----------------------------------------------------------- | ------------------------------ | ------------------------------------------- |
| "Cannot specify both include_patterns and exclude_patterns" | Both pattern types specified   | Use only one pattern type                   |
| "Cannot specify both X and static Y"                        | Mixed rolling and static dates | Use only one date filter type per timestamp |