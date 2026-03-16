# User Management

Project Neo uses JWT-based authentication with local user accounts. Every API request (except the token and initial-credentials endpoints) requires a valid bearer token. Users are either regular users or administrators -- only administrators can create, update, or delete other user accounts.

## Authentication

```
POST /api/v1/token
```

Authenticates a user and returns a JWT access token. This endpoint follows the OAuth2 password grant flow and accepts `application/x-www-form-urlencoded` form data.

### Parameters (form data)

| Field | Type | Description |
|-------|------|-------------|
| `username` | string | Account username |
| `password` | string | Account password |

### Example

```bash
curl -s -X POST http://localhost:8000/api/v1/token \
  -d "username=admin&password=yourpassword"
```

### Response

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

For convenience in subsequent requests, capture the token into a shell variable:

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/token \
  -d "username=admin&password=yourpassword" | jq -r .access_token)
```

Every example on this page uses this `$TOKEN` variable.

### Error Responses

| Status | Detail | Cause |
|--------|--------|-------|
| 401 | Incorrect username or password | Invalid credentials |
| 403 | User account is disabled | The `is_active` flag is `false` |

## Logout

```
POST /api/v1/logout
```

JWT tokens are stateless, so logout is handled client-side by discarding the token. This endpoint exists for API completeness and always returns a success message.

```bash
curl -s -X POST http://localhost:8000/api/v1/logout \
  -H "Authorization: Bearer $TOKEN"
```

## Current User

```
GET /api/v1/users/me
```

Returns information about the currently authenticated user.

### Example

```bash
curl -s http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Response

```json
{
  "id": 1,
  "username": "admin",
  "email": "admin@example.com",
  "is_active": true,
  "is_admin": true,
  "created_at": "2026-03-01T12:00:00Z",
  "last_login": "2026-03-10T09:15:00Z",
  "entra_object_id": null,
  "entra_tenant_id": null,
  "entra_display_name": null,
  "entra_linked_at": null
}
```

The `entra_*` fields are populated when the user account is linked to a Microsoft Entra ID identity for Copilot integration.

## Change Password

```
PATCH /api/v1/users/me/password
```

Changes the current user's password. Requires the existing password for verification.

### Request Body

| Field | Type | Description |
|-------|------|-------------|
| `current_password` | string | The user's current password |
| `new_password` | string | The new password to set |

### Example

```bash
curl -s -X PATCH http://localhost:8000/api/v1/users/me/password \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "current_password": "YOUR_CURRENT_PASSWORD_HERE",
    "new_password": "YOUR_NEW_PASSWORD_HERE"
  }'
```

### Response

```json
{
  "message": "Password changed successfully"
}
```

Returns `400 Bad Request` if `current_password` does not match.

## List Users (Admin)

```
GET /api/v1/users
```

Returns all user accounts. Requires administrator privileges.

### Example

```bash
curl -s http://localhost:8000/api/v1/users \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Response

```json
[
  {
    "id": 1,
    "username": "admin",
    "email": null,
    "is_active": true,
    "is_admin": true,
    "created_at": "2026-03-01T12:00:00Z",
    "last_login": "2026-03-10T09:15:00Z",
    "entra_object_id": null,
    "entra_tenant_id": null,
    "entra_display_name": null,
    "entra_linked_at": null
  },
  {
    "id": 2,
    "username": "analyst",
    "email": "analyst@example.com",
    "is_active": true,
    "is_admin": false,
    "created_at": "2026-03-05T08:00:00Z",
    "last_login": null,
    "entra_object_id": null,
    "entra_tenant_id": null,
    "entra_display_name": null,
    "entra_linked_at": null
  }
]
```

## Create User (Admin)

```
POST /api/v1/users
```

Creates a new user account. Requires administrator privileges. Returns `400 Bad Request` if the username already exists.

### Request Body

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `username` | string | *(required)* | Unique username |
| `password` | string | *(required)* | Initial password |
| `email` | string | `null` | Email address |
| `is_admin` | boolean | `false` | Grant administrator privileges |

### Example

```bash
curl -s -X POST http://localhost:8000/api/v1/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "analyst",
    "password": "YOUR_PASSWORD_HERE",
    "email": "analyst@example.com",
    "is_admin": false
  }'
```

### Response (201 Created)

```json
{
  "id": 2,
  "username": "analyst",
  "email": "analyst@example.com",
  "is_active": true,
  "is_admin": false,
  "created_at": "2026-03-10T14:00:00Z",
  "last_login": null,
  "entra_object_id": null,
  "entra_tenant_id": null,
  "entra_display_name": null,
  "entra_linked_at": null
}
```

## Get User (Admin)

```
GET /api/v1/users/{user_id}
```

Returns a specific user by numeric ID. Requires administrator privileges.

```bash
curl -s http://localhost:8000/api/v1/users/2 \
  -H "Authorization: Bearer $TOKEN" | jq
```

## Update User (Admin)

```
PATCH /api/v1/users/{user_id}
```

Updates one or more fields on an existing user account. Requires administrator privileges. All fields are optional -- only include the fields you want to change.

### Request Body

| Field | Type | Description |
|-------|------|-------------|
| `email` | string | Updated email address |
| `password` | string | New password (hashed automatically) |
| `is_active` | boolean | Enable or disable the account |
| `is_admin` | boolean | Grant or revoke admin privileges |

### Example -- Disable a User

```bash
curl -s -X PATCH http://localhost:8000/api/v1/users/2 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "is_active": false
  }'
```

### Example -- Promote to Admin

```bash
curl -s -X PATCH http://localhost:8000/api/v1/users/2 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "is_admin": true
  }'
```

Returns the updated user object on success. Returns `400 Bad Request` if no update fields are provided.

## Delete User (Admin)

```
DELETE /api/v1/users/{user_id}
```

Permanently deletes a user account. Requires administrator privileges. You cannot delete your own account.

### Example

```bash
curl -s -X DELETE http://localhost:8000/api/v1/users/2 \
  -H "Authorization: Bearer $TOKEN"
```

### Response

```json
{
  "message": "User deleted",
  "user_id": 2
}
```

Returns `400 Bad Request` if you attempt to delete yourself.

## Create Admin User

```
POST /api/v1/users/admin
```

A convenience endpoint for creating users with administrator privileges. The `is_admin` flag is forced to `true` regardless of the request body. Requires an existing admin token.

### Request Body

| Field | Type | Description |
|-------|------|-------------|
| `username` | string | Unique username |
| `password` | string | Initial password |

### Example

```bash
curl -s -X POST http://localhost:8000/api/v1/users/admin \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "backup_admin",
    "password": "YOUR_PASSWORD_HERE"
  }'
```

## Initial Credentials

```
GET /api/v1/setup/initial-credentials
```

Retrieves the auto-generated admin password that was created during first startup. This endpoint does **not** require authentication.

::: warning Security
This endpoint is only available before the admin user's first login. After the admin logs in, the stored password is permanently deleted and this endpoint returns `403 Forbidden`. Retrieve the credentials promptly after deployment and change the password immediately.
:::

### Example

```bash
curl -s http://localhost:8000/api/v1/setup/initial-credentials | jq
```

### Response

```json
{
  "username": "admin",
  "password": "YOUR_AUTO_GENERATED_PASSWORD_HERE",
  "message": "Please change this password immediately after logging in. This endpoint will be disabled after first login."
}
```

### Error Responses

| Status | Cause |
|--------|-------|
| 403 | Admin user has already logged in; credentials are no longer available |
| 404 | Initial credentials not found (manual setup or already retrieved and deleted) |

## First-Time Setup Workflow

1. Deploy Neo and wait for the services to start.
2. Retrieve the auto-generated password:
   ```bash
   curl -s http://localhost:8000/api/v1/setup/initial-credentials | jq
   ```
3. Authenticate with the initial credentials:
   ```bash
   TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/token \
     -d "username=admin&password=YOUR_AUTO_GENERATED_PASSWORD_HERE" | jq -r .access_token)
   ```
4. Change the admin password immediately:
   ```bash
   curl -s -X PATCH http://localhost:8000/api/v1/users/me/password \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "current_password": "YOUR_AUTO_GENERATED_PASSWORD_HERE",
       "new_password": "YOUR_NEW_PASSWORD_HERE"
     }'
   ```
5. Create additional user accounts as needed using the admin endpoints above.
