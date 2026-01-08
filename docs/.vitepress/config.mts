import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: '/Innovation-Labs/',
  lastUpdated: true,
  ignoreDeadLinks: true,
  title: "NetApp Innovation Labs",
  description: "This is the gateway to explore and experiment with our Early Access Software. By participating, you can help shape the future development and direction of these cutting-edge solutions.",
  themeConfig: {
    search: {
      provider: 'local'
    },
    siteTitle: "Innovation Labs",
    logo: {
      light: 'n-black.svg',
      dark: 'n-white.svg',
      alt: 'NetApp Logo'
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Content Posts', link: '/content/posts' },
      { text: 'Projects', link: '/projects' },
      { text: 'Legal Notice', link: '/projects/legal-notices' },
    ],

    sidebar: [
      { text: 'Content Posts', link: '/content/posts' },
      { text: 'Projects', link: '/projects', },
      { text: 'Legal Notice', link: '/projects/legal-notices' },
      {
        text: 'Cloud',
        items: [
          { text: 'AWS Outpost iSCSI Support', link: '/projects/cloud/aws-outpost-iscsi-support' },
        ]
      },
      {
        text: 'Containers',
        items: [
          { text: 'Consoles for OpenShift', link: '/projects/containers/openshift-consoles', 
            items: [
              { text: 'License', link: '/projects/containers/LICENSE' },
              { text: 'Notice', link: '/projects/containers/NOTICE.md'}
            ]
          },
        ]
      },
      {
       text: 'ML/AI', 
       items: [
        { 
          text: 'Neo', link: '/projects/neo/core/overview',
          collapsed: true,
          items: [
            { text: 'Introduction', link: '/projects/neo/core/introduction' },
            { text: 'Release Notes', link: '/projects/neo/core/release-notes',
              items: [
                { text: 'Core', link: '/projects/neo/core/rn-core' },
                { text: 'Console', link: '/projects/neo/core/rn-console' },
              ],
             },
            { text: 'Prerequisites', link: '/projects/neo/core/prerequisites' },
            { text: 'Quick Start', link: '/projects/neo/core/quick-start', 
              items: [
                { text: 'Kubernetes', link: '/projects/neo/core/qs-kubernetes' },
                { text: 'Docker/Podman', link: '/projects/neo/core/qs-docker' },
              ],
            },
            { text: 'Deployment', link: '/projects/neo/core/deployment',
              items: [
                { text: 'Configuration', link: '/projects/neo/core/d-configuration' },
                { text: 'Sizing', link: '/projects/neo/core/d-sizing' },
                { text: 'Upgrades', link: '/projects/neo/core/d-upgrades' },
              ],
             },
            { text: 'Management', link: '/projects/neo/core/management', 
              items: [
                { text: 'Neo Console', link: '/projects/neo/core/m-console' },
                { text: 'Microsoft 365 Copilot', link: '/projects/neo/core/m-m365-copilot.md' },
                { text: 'API', link: '/projects/neo/core/m-api' },
                { text: 'MCP', link: '/projects/neo/core/m-mcp' },
                { text: 'Users', link: '/projects/neo/core/m-users' },
                { text: 'Shares', link: '/projects/neo/core/m-shares' },
                { text: 'Files', link: '/projects/neo/core/m-files' },
                { text: 'Rules & Filters', link: '/projects/neo/core/m-rules-filters' },
                { text: 'Items Level Permissions', link: '/projects/neo/core/m-acls' },
                { text: 'Shares', link: '/projects/neo/core/m-shares' },
              ],
            },
            { text: 'Security', link: '/projects/neo/core/security' },
            { text: 'Troubleshooting', link: '/projects/neo/core/troubleshooting'},
            { text: 'Notice', link: '/projects/neo/core/NOTICE.md' },
          ],
        },
        { text: 'Neo UI Framework', link: '/projects/neo/uif/ui-framework' },
        { text: 'Neo Fuse Client', link: '/projects/neo/nfc/fuse-client' },
          ]
      },        
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/NetApp/Innovation-Labs', ariaLabel: 'GitHub' }
    ],
    footer: {
      copyright: 'Copyright © 2025 NetApp'
    }
  }
})
