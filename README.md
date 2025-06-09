# Innovation-Labs Helm Chart Repository

Welcome to **NetApp Innovation Labs**! This is your gateway to explore and experiment with our early access software. By participating, you can help shape the future development and direction of these cutting-edge solutions.

**Please note that all software is subject to the NetApp [General Terms](https://www.netapp.com/how-to-buy/sales-terms-and-conditions/terms-with-customers/general-terms/general-terms/).**

## Getting Started

To get started with our Helm charts, follow these steps:

1. **Add the Helm Repository**: Use the following command to add our Helm repository to your local Helm client:
   ```bash
   helm repo add innovation-labs https://netapp.github.io/Innovation-Labs/
   ```
1. **Update Your Helm Repositories**: Make sure to update your local Helm repository cache:
   ```bash
   helm repo update
   ```
1. **List Available Charts**: You can view the available charts in our repository with:
   ```bash
   helm search repo innovation-labs
   ```
   Expected outputs:
    ```
    NAME                                    CHART VERSION   APP VERSION     DESCRIPTION
    innovation-labs/netapp-connector        2.0.6           2.0.6           A Helm chart for deploying netapp-connector as ...
    ```

## Installing Charts
To install a chart from our repository, refer to the specific chart's documentation for installation instructions.

1. NetApp Connector for M365 Copilot: [Documentation](https://github.com/NetApp/Innovation-Labs/blob/main/netapp-connector/README.md) & [Deployment Guide](https://github.com/NetApp/Innovation-Labs/blob/main/netapp-connector/helm/README.md)