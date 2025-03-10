# NetApp Connector for M365 Copilot

## Introduction

The NetApp Connector for M365 Copilot is a containerized solution that enables you to connect any NetApp platform to Microsoft M365 Copilot without the need to migrate or rearchitect your existing data architecture.

## Features

- Containerized Deployment - typical deployment time is less than 3 minutes
- API Interface - RESTful API for easy integration and management of the connector, replacing the need for M365 Search and Intelligence UI
- Enhanced filtering - filter data based on file type, size, and date
- Parallelization - multiple threads for faster data extraction, conversion and transfer
- Large Document Chunking - split large documents into smaller chunks for unlimited file ingestion into Microsoft Graph (MS Graph has a 3.8MB Content-Length limit, this feature allows for larger files to be ingested)
- Offline Licensing - no need to connect to the internet for licensing

## Getting Started

### Register the connector in Azure ENTRA

In order for the connector to be able to communicate with Microsoft 365 Copilot, it needs to be registered in Azure ENTRA.
![Select App Registration in the Add menu in Microsoft Azure Entra](netapp-connector/media/2025-03-10_20-17-27.png)

### Prerequisites

- SMB File Share(s) accessible from the machine where the connector will be deployed
- Microsoft 365 Copilot License
- Docker / Podman installed on the machine where the connector will be deployed
- Access to the offline tar image of the connector
- (Optional) Docker Compose installed on the machine where the connector will be deployed
- (Optional) Access to a Kubernetes cluster for deployment

## Roadmap

Roadmap for the NetApp Connector for M365 Copilot is shared under an NDA. Please reach out to your NetApp representative for more information.

## Support

For any questions or issues, please open an issue in this repository.
