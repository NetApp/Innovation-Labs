# Neo UI Framework

The Neo UI Framework provides the web-based management console for NetApp Project Neo. The console is available at port 8081 and connects to the API service on port 8000.

## Overview

The Neo UI is a browser-based interface for:

- **Setup Wizard** — Initial configuration (license, Microsoft Graph, SSL, proxy)
- **Share Management** — Add, edit, and delete data source connections (SMB, NFS, S3)
- **Monitoring** — View crawl progress, work queue status, and service health
- **Search** — Full-text search across indexed content
- **User Management** — Create and manage user accounts
- **NER Results** — Browse named entity recognition results

## Deployment

The UI runs as a separate container (`neoui`) and is included in the standard Docker Compose deployment:

```yaml
neoui:
  image: ghcr.io/beezy-dev/neo-ui-framework:3.2.2
  ports:
    - "8081:80"
  environment:
    NEO_API: http://api:8000
```

Access the console at `http://your-server:8081` after deployment.

## Documentation

For console usage details, see the [Console Guide](../core/m-console.md).

The UI Framework is maintained separately at [beezy-dev/neo-ui-framework](https://github.com/beezy-dev/neo-ui-framework).
