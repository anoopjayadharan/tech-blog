# Blog Template for AWS DevOps Engineer Bootcamp Participants

[![Release](https://github.com/anoopjayadharan/tech-blog/actions/workflows/blog-release.yml/badge.svg)](https://github.com/anoopjayadharan/tech-blog/actions/workflows/blog-release.yml)

Welcome to the Blog Template designed for participants of the **FREE** AWS DevOps Engineer Bootcamp offered by the [Cloud Talents community](https://www.skool.com/cloudtalents/about)! 

This repository provides a starting point for creating your own blog to document your journey through the bootcamp.

## Table of Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuration](#configuration)
- [Running the Blog Locally](#running-the-blog-locally)
- [Building the Blog](#building-the-blog)
- [About the AWS Bootcamp](#about-the-aws-bootcamp)
- [Contributing](#contributing)
- [License](#license)

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- [Git](https://git-scm.com/downloads)
- [Hugo](https://gohugo.io/getting-started/installing/) (Extended version recommended)

### Installation

1. **Fork the Repository**

   Click the "Fork" button at the top-right corner of this repository to create your own copy.

2. **Clone Your Fork**

   ```bash
   git clone https://github.com/yourusername/your-forked-repo.git
   ```

3. **Navigate to the Project Directory**

   ```bash
   cd your-forked-repo
   ```

### Configuration

Customize your blog by replacing placeholder variables in the `hugo.toml` file:

- **`NAME_OF_YOUR_BLOG`**: Replace with the title of your blog.
- **`LINK_TO_YOUR_PHOTO_BELOW`**: Replace with the URL to your personal photo.
- **`YOUR_LINKEDIN_LINK`**: Replace with the link to your LinkedIn profile.
- **`YOUR_NAME`**: Replace with your full name.

Open `hugo.toml` in a text editor and make the necessary changes.

## Running the Blog Locally

Start the Hugo development server to view your blog locally:

```bash
hugo server -D
```

- **`-D`**: Includes content marked as drafts.

Open your web browser and navigate to **[http://localhost:1313](http://localhost:1313)** to see your blog in action.

## Building the Blog

Generate the static files for deployment:

```bash
hugo
```

- The generated files will be located in the `public/` directory.
- You can deploy these files to any static hosting service.

## About the AWS DevOps Engineer Bootcamp

This blog template is part of the **FREE** [Cloud Talents AWS DevOps Enginneer Bootcamp](https://www.skool.com/cloudtalents/about), a program for individuals interested in learning Amazon Web Services and DevOps practices. 

The bootcamp covers a wide range of AWS services and provides hands-on experience through practical assignments.

- **Website**: [AWS DevOps Engineer Bootcamp](https://www.skool.com/cloudtalents/about)

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Happy blogging and enjoy your journey through the AWS Bootcamp!
