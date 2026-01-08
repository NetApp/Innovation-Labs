# Contributing to Documentation

Thank you for your interest in improving our documentation! This site is built with [VitePress](https://vitepress.dev/) and covers the NetApp Innovations Labs projects.

## Project Structure

* **```docs/```**: The source code for the documentation site.
    * **```docs/content/```**: Portfolio of our team's contribution to blogs, videos, etc.
    * **```docs/projects/[cloud,containers,mlai]```**: Documentation per domain
    * **`docs/.vitepress/`**: Site configuration, theme, and sidebar settings.

## Local Development

To update and preview documentation changes locally before pushing:

1.  **Prerequisites**
    * [Node.js](https://nodejs.org/en/download) (version 20 or higher)
    * npm (comes with Node.js)
    * Fork the [NetApp Innovation Labs](https://github.com/NetApp/Innovation-Labs) repository

2.  **Setup**
    ```bash
    # Install dependencies
    npm install
    ```

3.  **Run the Dev Server**
    ```bash
    npm run docs:dev
    ```
    The site will start at ```http://localhost:5173```. Any changes you make to markdown files will hot-reload automatically.

## Writing Guidelines

We use native and GitHub Markdown without any HTML or add-ons with VitePress extensions and follow the categories/subcategories of the existing content.

### Adding a New Page
1.  Create a ```.md``` file in the appropriate directory (e.g., ```docs/projects/cloud/my-new-project.md```).
2.  Add the file to the **sidebar** (not the **nav**) in ```docs/.vitepress/config.mts``` so it appears in the sidebar navigation menu.

### images
Place images in the ```docs/public``` folder and reference with the markdown tag   
```![Description of image](/my-image.png)```

## Publishing
Once you are happy with your content, open a Pull Request from your repository towards ours and we will review your contributions! 