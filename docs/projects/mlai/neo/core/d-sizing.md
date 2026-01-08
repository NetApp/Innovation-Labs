# Sizing Guide

## NetApp Core Nodes

### POC Environment

- 4 vCPU / 8GB RAM per node

### Production Environment

- 8 vCPU / 16GB RAM per node

## Database Sizing

The database requirements will depend on the size of your data and the number of users. As a general guideline:

- Database Size: 2GB for every 100 GB of documents indexed (2% of source data size)