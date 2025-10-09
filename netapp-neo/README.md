# NetApp Neo: Connector for M365 Copilot

## Introduction

The NetApp Neo: Connector for M365 Copilot is a containerized solution that enables you to connect any NetApp platform to Microsoft M365 Copilot without the need to migrate or rearchitect your existing data architecture.

> [!IMPORTANT]
> The NetApp Neo: Connector for M365 Copilot is currently in **Private Preview**. This means that the connector is not yet fully supported and may have some limitations. The connector requires a license to activate. You can request access to the connector by joining the Early Access Program (EAP). Please book a meeting with the following link to join the EAP: [Book a meeting with NetApp](https://outlook.office.com/bookwithme/user/d636d7a02ad8477c9af9a0cbb029af4d@netapp.com/meetingtype/nm-mXkp-TUO1CdzOmFfIBw2?anonymous&ismsaljsauthenabled&ep=mlink).

## Features

- **OCR and Optimized Extraction** - the connector automatically extracts accurate text from complex documents, making it easier to search and find relevant information in your files (the only connector in the market to provide this feature)
- **GPU Support** - the connector can leverage GPU acceleration for 2-5x faster data extraction and conversion, improving performance and reducing processing time (this is a world-first for a Copilot connector)
- **Containerized Deployment** - typical deployment time is less than 3 minutes
- **Multiple Source Support** - supports SMB File Shares (v3.1.1 through v2.0) including:
  - Azure NetApp Files (ANF)
  - AWS FSxN
  - Google Cloud Volumes NetApp (GCVN)
  - Cloud Volumes ONTAP (CVO)
  - Any ONTAP-based system (FAS, AFF, Select, etc.)
  - Any SMB file share (non-NetApp) that supports SMB v3.1.1 through v2.0
- **No Data Migration Required** - connect your existing NetApp storage to M365 Copilot
- **Item level permissioning** - the connector will automatically extract and convert files from the source file share and transfer them to Microsoft Graph, preserving item-level permissions
- **API Interface** - RESTful API for easy integration and management of the connector, replacing the need for M365 Search and Intelligence UI
- **Enhanced filtering** - filter data based on file type, size, and date
- **Parallelization** - multiple threads for faster data extraction, conversion and transfer
- **Large Document Chunking** - split large documents into smaller chunks for unlimited file ingestion into Microsoft Graph (MS Graph has a 3.8MB Content-Length limit, this feature allows for larger files to be ingested)
- **Offline Licensing** - no need to connect to the internet for licensing

## Getting Started

Want to get up and running quickly? Head over to  

- the Neo v3.x [User Quickstart for M365](./USER_QUICKSTART_M365.md) guide for a step-by-step guide to deploying the connector and connecting your first share.
- the Neo v2.x (**phasing out**) [User Quickstart for M365](./DEPLOY-V2.md) guide for a step-by-step guide to deploying the connector and connecting your first share.

## Security Information

The NetApp Neo: Connector for M365 Copilot is designed with security in mind. All relevant security information is available in the [Security Information](SECURITY.md) document. This includes information on how the connector handles data, how it communicates with Microsoft Graph, and how it is secured.

## Frequently Asked Questions (FAQ)
Most frequently asked questions are available in our [NEO FAQ](FAQ.md)

## Support

For any questions or issues, please open an issue in this repository.

## License

**Please note that use of this software is subject to the NetApp [General Terms](https://www.netapp.com/how-to-buy/sales-terms-and-conditions/terms-with-customers/general-terms/general-terms/).**
