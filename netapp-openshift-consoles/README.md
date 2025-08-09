# NetApp OpenShift Console Plugins for Red Hat OpenShift

Welcome to the NetApp OpenShift Console Plugins, a suite of open-source projects designed to significantly improve how you interact NetApp storage within your Red Hat OpenShift environment. These native OpenShift console plugins bring powerful storage and data management capabilities directly to your fingertips, simplifying complex tasks and accelerating your development and deployment workflows.

## Why Use the NetApp Console Plugins?
Managing persistent storage for critical workload can be complex, especially in a containerized environment. Our plugins solve this by providing an intuitive graphical user interface (GUI) inside the OpenShift console, allowing you to:

* Accelerate Deployment: Quickly deploy Trident, NetApp's dynamic storage orchestrator for Kubernetes, and Trident Protect with just a few clicks.
* Simplify Storage Management: Effortlessly create and manage volumes, snapshots, and business continuity directly from the console. No more command-line gymnastics!
* Enable Dataset Management: Take control of your data, particularly for workloads running in OpenShift, OpenShift AI, and Developer Hub. This is perfect for data-intensive and AI/ML projects.

## Console Plugins
We offer two powerful plugins to meet your storage management needs:

1. netapp-openshift-console-trident
This is your plugin for core Trident functionalities. It provides an intuitive GUI to:

* Manage volumes and snapshots.
* Create clones from snapshots. 
* Import existing NetApp volumes to Red Hat OpenShift, even if not created with Trident
* Expose volumes to Red Hat OpenShift AI for advanced data engineering workflows

2. netapp-openshift-console-protect
This is your plugin for workload protection with Trident Protect. It provides a simplified GUI to:

* Create, schedule, and trigger on-demand application-aware local backups 
* Create, schedule, and trigger on-demand application-aware remote backups 
* Manage in-place restore
* Manage restore as a new workload

## Getting Started
Both projects are currently in a pre-release phase and require an Early Access Program agreement. This agreement will grant you the necessary access token to deploy the plugins on your OpenShift cluster.

Prerequisites
* Red Hat OpenShift Container Platform 4.14, 4.15, 4.16, or 4.17.
* An access token from the Early Access Program.

## Documentation
Comprehensive documentation for both plugins is available [here](./DOC.md).

Note: These projects are provided AS-IS under the Apache 2.0 License with community support only. For any questions or issues, please open a GitHub Issue.