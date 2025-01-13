---
title: 'A Taste of DevOps(My Tech-Blog)'
date: 2024-11-02
tags: ["AWS", "devOps", "Git", "GitHub Actions", "Terraform"]
categories: ["Documentation"]
draft: false
---

The landscape of cloud services adoption, especially among startups, has evolved significantly. Companies no longer rush to leverage core cloud services when transitioning workloads to a public cloud environment. Instead, a more strategic approach is being embraced.

Initially, organizations establish a landing zone where they begin by utilizing managed cloud services. This approach often involves hosting a static website to comprehensively understand cloud solutions. Subsequently, the focus shifts towards automating website releases through a CI/CD pipeline. This streamlined process enhances efficiency and accelerates time to market, providing companies with a tangible experience of DevOps practices.

In this blog, I delve into the intricacies of serving a static website on the AWS cloud using CloudFront and an S3 bucket. Key features of this setup include:

- GitHub serves as a centralized source code management platform.
- Utilizing Terraform, a versatile Infrastructure as Code (IaC) tool, to construct the cloud infrastructure, Amazon S3, and CloudFront.
- Implementation of GitHub Actions to automate the CI/CD workflow.
- Integration of HCP (HashiCorp Cloud Platform) as a remote backend for Terraform operations.
- AWS plays a pivotal role as the chosen public cloud provider.

### Diagram

{{< figure src="/images/diagram.PNG" title="Figure1: Overview" >}}


A workflow is triggered when a developer pushes code to the main branch. The workflow has three jobs defined:

- Provision the AWS infrastructure based on the terraform directory code changes.
- Build the blog using the static website generator Hugo.
- Update the S3 bucket with the new contents and invalidate the CloudFront cache. 

### GitHub Repository
  Source code can be found in this **[GitHub Repo](https://github.com/anoopjayadharan/tech-blog)**


### CI/CD Workflow
The **infra_job** checks out the current repository and executes the Terraform workflow in **HCP Terraform** . The [HashiCorp—Setup Terraform](https://github.com/marketplace/actions/hashicorp-setup-terraform) action installs the Terraform CLI on a GitHub-hosted runner. A few placeholders are passed to the [GITHUB_OUTPUTS](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/passing-information-between-jobs) for later use in subsequent jobs.

### Intra_job

```YAML
jobs:
    Infra_job:
        name: AWS Infrastructure Provisioning with Terraform
        runs-on: ubuntu-latest
        defaults:
          run:
            working-directory: terraform

        # s3_bucket name and cloudfront distribution ids are stored
        # as outputs and will be passed to "deploy_job"

        outputs:
          s3_bucket: ${{ steps.tf_out.outputs.s3 }}
          cf_id: ${{ steps.tf_out.outputs.cfid }}

        steps:
            - name: Checkout Repository
              uses: actions/checkout@v4

            - name: Terraform Workflow
              uses: hashicorp/setup-terraform@v3
              with:
                terraform_version: "1.9.7"
                cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}     # API_TOKEN for HCP Terrafom

            - name: Terraform Init
              id: init
              run: terraform init

            - name: Terraform Validate
              id: validate
              run: terraform validate -no-color

            - name: Terraform Plan
              id: plan
              run: terraform plan -no-color
              continue-on-error: true

            - name: Terraform Apply
              id: Apply
              run: terraform apply -auto-approve

            - name: Terraform Output
              id: tf_out
              run: |
                echo "s3=$(terraform output s3_bucket | tr -d '""')" >> "$GITHUB_OUTPUT"
                echo "cfid=$(terraform output cloudFront_ID | tr -d '""')" >> "$GITHUB_OUTPUT"
                echo "domain=$(terraform output cloudFront_domain_name | tr -d '""')" >> "$GITHUB_OUTPUT"
```
{{< admonition >}}
Successful completion of `infra_job` will create the following resources on the `HCP Terraform`

{{< /admonition >}}

{{< figure src="/images/HCP%20Overview.PNG" title="Figure2: Resources" >}}

### Build_job
The **build_job** is the easiest of all. It uses [Hugo setup](https://github.com/marketplace/actions/hugo-setup) actions to install and build our website. The build **Artifacts** are uploaded using the [Upload a Build Artifact](https://github.com/marketplace/actions/upload-a-build-artifact) GitHub action. 
```YAML
build_job:
        name: Build
        needs: [Infra_job]
        runs-on: ubuntu-latest

        steps:
            - name: Checkout Repository
              uses: actions/checkout@v4

            - name: Setup Hugo
              uses: peaceiris/actions-hugo@v3
              with:
                hugo-version: '0.135.0'
                extended: true

            - name: Build
              run: hugo

            - name: Upload Build Artifact
              uses: actions/upload-artifact@v4
              with:
                name: tech-blog
                path: public/* 
```

### Deploy_job
The final job is to publish the website by deploying the **Artifacts** generated in the build_job to **Amazon S3**. Here, we use OIDC integration between GitHub and AWS for the GitHub runner to leverage AWS CLI for running s3 sync and cache-invalidation commands. 

```YAML
deploy_job:
        name: Publish
        needs: [build_job, Infra_job]
        env:
          S3_BUCKET: ${{needs.Infra_job.outputs.s3_bucket}}
          DISTRIBUTION_ID: ${{needs.Infra_job.outputs.cf_id}}
        runs-on: ubuntu-latest
        permissions:
          id-token: write     # This is required for requesting the JWT
          contents: read      # This is required for actions/checkout

        steps:
            - name: Download Build Artifacts
              uses: actions/download-artifact@v4
              with:
                name: tech-blog

            - name: Configure AWS credentials
              uses: aws-actions/configure-aws-credentials@v4
              with:
                role-to-assume: ${{secrets.AWS_IAM_ROLE}}
                aws-region: ${{ env.AWS_REGION }}

            - name: S3 sync
              run: | 
                aws s3 sync . s3://${{env.S3_BUCKET}} \
                --delete

            - name: Create CloudFront Invalidation
              run: |
                aws cloudfront create-invalidation \
                --distribution-id ${{env.DISTRIBUTION_ID}} \
                --paths "/*"
```
### Workflow Summary
{{< admonition info>}}
The workflow summary page shows the successful completion of all jobs and the generated Artifact

{{< /admonition >}}

{{< figure src="/images/summary.PNG" title="Figure3: Workflow Summary" >}}

Hence, all future releases are automated using GitHub actions CI/CD workflow. This setup can be further improved by creating a feature branch and testing changes before merging to the main branch. 

### Reference

- [HashiCorp—Setup Terraform](https://github.com/marketplace/actions/hashicorp-setup-terraform)

- [GITHUB_OUTPUTS](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/passing-information-between-jobs)
