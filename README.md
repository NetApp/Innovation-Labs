# Innovation-Labs

Welcome to **NetApp Innovation Labs**!

This is your gateway to explore and experiment with our Early Access Software. By participating, you can help shape the future development and direction of these cutting-edge solutions.

> [!IMPORTANT]
> Please note that all software is subject to the NetApp [General Terms](https://www.netapp.com/how-to-buy/sales-terms-and-conditions/terms-with-customers/general-terms/general-terms/).

## Lab Directory

- [NetApp Neo: Connector for M365 Copilot](https://netapp.github.io/Innovation-Labs/projects/neo/core/overview.html)
- [NetApp Console Plugins for Red Hat OpenShift](./netapp-openshift-consoles/README.md)
- [NetApp Hybrid RAG (BM25-based) Deployment Guide](./docs/projects/hybrid-rag-bm25/README.md)
- [NetApp Graph RAG Deployment Guide](./docs/projects/graph-rag/README.md)
- [NetApp BM25-based/Document RAG Deployment Guide](./docs/projects/document-rag/README.md)

## Getting Started

To get started with our solutions, add the NetApp Innovation Labs [Helm charts](https://netapp.github.io/Innovation-Labs/) to your collection:

1. Add the repository to your local collection:
   ```
   helm repo add innovation-labs https://netapp.github.io/Innovation-Labs/
   ```
1. Update the repository to the latest release:
   ```
   helm repo update
   ```
1. List the available Helm charts:
   ```
   helm search repo innovation-labs
   ```
   Expected outputs:
   ```
   NAME                                                    CHART VERSION   APP VERSION     DESCRIPTION
   innovation-labs/netapp-connector                        2.1.13          2.1.4           A Helm chart for deploying netapp-connector as ...
   innovation-labs/netapp-openshift-console-protect        25.7.1          25.6.25         NetApp Console Plug-in for Red Hat OpenShift pr...
   innovation-labs/netapp-openshift-console-trident        25.7.1          25.6.25         NetApp Console Plugin for Red Hat OpenShift pro...
   ```
