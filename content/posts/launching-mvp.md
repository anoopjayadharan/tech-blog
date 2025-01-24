---
title: 'Launching MVP'
date: 2024-11-15
tags: ["AWS", "EC2",  "Postgres", "Bash", "Packer", "Terraform", "GitHub Actions"]
categories: ["DevOps"]
---

Last week, AWS VPC resources were defined in a [Network account](https://www.devopsifyengineering.com/network/) and shared across the accounts in the Sandbox OU <!--more-->

It's time to launch the `MVP`(minimum viable product). The developer has pushed the source code to a Github repo. As a DevOps engineer, your task is to build the system and publish the service for initial testing.


### Application Overview
- It is written in Python and uses the Django web framework. 
- NGINX serves as a reverse proxy. 
- Gunicorn implements the web server gateway interface(WSGI), translating HTTP requests into something Python can understand. 
 - Postgres is the chosen database for storing the authenticated user data. 

{{< figure src="/images/App_diagram.PNG" title="Figure1: App components" >}}

{{< admonition >}}
All these components fit in an EC2 instance and serve the purpose. 
{{< /admonition >}}



There are a handful of tasks out there for DevOps Engineers;
- Building a custom AMI using HashiCorp Packer and Bash scripting
- Infrastructure provision by Terraform
- Managing CI/CD pipeline through GitHub Actions

### Implementation
The diagram depicts two CI/CD workflows. One builds the AMI using Packer, and the other deploys an EC2 from the custom AMI. Why Packer? We aim to build immutable images and deploy them without additional configuration. Using Packer, a custom AMI is built from the parent image(Ubuntu) using a BASH script. The script installs the necessary packages and sets up a Python environment for our application to run. For every GitHub release, an AMI gets created corresponding to the release version.

{{< figure src="/images/mvp-Diagram.PNG" title="Figure2: Diagram" >}}

The `ec2.yml` workflow is set to manual trigger with an input variable "version." This ensures that the application release matches the AMI version. 

Take a look at the packer template below. Two plugins are being used. The `amazon` is used to build AMI on AWS, and `amazon-ami-management` is our post-processor plugin, which keeps only the last 2 releases of your AMI. 

```hcl
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
  required_plugins {
    amazon-ami-management = {
      version = ">= 1.0.0"
      source  = "github.com/wata727/amazon-ami-management"
    }
  }
}

variable "subnet_id" {}
variable "vpc_id" {}
variable "version" {}

locals {
  ami_name          = "devopsify-engineering"
  source_ami_name   = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server*"
  source_ami_owners = ["099720109477"]
  ssh_username      = "ubuntu"
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "${local.ami_name}-${var.version}"
  instance_type = "t2.micro"
  region        = "eu-west-1"
  source_ami_filter {
    filters = {
      name                = local.source_ami_name
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = local.source_ami_owners
  }
  ssh_username                = local.ssh_username
  vpc_id                      = var.vpc_id
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  tags = {
    Amazon_AMI_Management_Identifier = local.ami_name
  }
}

build {
  name = "custom_ami"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
  provisioner "file" {
    source      = "./"
    destination = "/tmp"
  }
  provisioner "shell" {
    inline = [
      "echo Moving files...",
      "sudo mkdir -p /opt/app",
      "sudo mv /tmp/* /opt/app",
      "sudo chmod +x /opt/app/setup.sh"
    ]
  }
  provisioner "shell" {
    script = "setup.sh"
  }
  post-processor "amazon-ami-management" {
    regions       = ["eu-west-1"]
    identifier    = local.ami_name
    keep_releases = 2
  }
}
```

The AMI details are provided in the `source` block, which is triggered by the `build` block underneath. The build block defines a couple of provisioner blocks to leverage file transfer and script execution. The packer build command requires a few arguments, such as `vpc_id` and `subnet_id`, which are defined as variables. 

Let us move on to the `image.yml` workflow file. This workflow is triggered every time a new release is published. Within `build_job` step 6, secrets.sh gets created to store the DB credentials. Security-minded people out there, I know this is not a recommended practice. In the upcoming post, I will use AWS-managed services to store the secrets. Okay, back to the workflow. GitHub Actions uses [OIDC integration with AWS](https://www.devopsifyengineering.com/oidc-github-aws/). In the last step, the packer builds the image, and we use the value of github.ref_name as the version. This value replaces the AMI version in the packer template.

```yaml
name: private_ami

on:
    release:
        types: [published]

env:
   AWS_REGION: "eu-west-1"
   PACKER_VERSION: "1.11.2"

jobs:
    build_image:
        name: packer build
        runs-on: ubuntu-latest

        # Permissions to create the OIDC JWT
        permissions:
            id-token: write
            contents: read

        steps:
            # Step 1 - Checkout Repository
            - name: Repository Checkout
              uses: actions/checkout@v4

            # Step 2 - Install packer v1.11.2
            - name: Setup `packer`
              uses: hashicorp/setup-packer@main
              id: setup
              with:
                version: ${{ env.PACKER_VERSION }}

            # Step 3 - Packer init
            - name: Run `packer init`
              id: init
              run: "packer init ./image.pkr.hcl"
            
            # Step 4 - Decalre Environment variables
            - name: Script
              run: |
                sudo cat > secrets.sh <<EOF
                #!/bin/bash
                export SECRET_KEY='${{ secrets.SECRET_KEY }}'
                export DB_USER='${{ secrets.DB_USER }}'
                export DB_PASSWORD='${{ secrets.DB_PASSWORD }}'
                EOF

            # Step 5 - Setup AWS CLI
            - name: Configure AWS credentials
              uses: aws-actions/configure-aws-credentials@v4
              with:
                role-to-assume: ${{ secrets.IAM_ROLE_ARN }}
                aws-region: ${{ env.AWS_REGION }}

            # Step 6 - Packer build
            - name: Run `packer build`
              run: packer build -color=false -on-error=abort -var "vpc_id=${{ secrets.VPC_ID }}" -var "subnet_id=${{ secrets.SUBNET_ID }}" -var "version=${{ github.ref_name }}" ./image.pkr.hcl 
```
### Output

{{< admonition info>}}
A new release has been published
{{< /admonition >}}

{{< figure src="/images/github%20release.PNG" title="Figure3: GitHub Release" >}}

{{< admonition tip>}}
Packer run produces below output
{{< /admonition >}}

{{< figure src="/images/packer%20build%20-%20github.PNG" title="Figure4: Packer Build" >}}

{{< admonition tip "Amazon Machine Image">}}
{{< /admonition >}}

{{< figure src="/images/AMI.PNG" title="Figure5: AMI" >}}

Next, we need to deploy an EC2 instance from this custom AMI. Let's examine the `ec2.yml` workflow. The `launch_ec2` job uses terraform to deploy the instance. In the `terraform apply` command, an input variable named "AMI version" is being supplied. This ensures that the application release matches the AMI version.

```yaml
name: launch_ec2

on:
    workflow_dispatch:      # manual trigger
        inputs:             # provide ami_version as an input
            ami_version:
                description: 'AMI version'
                required: true
jobs:
    launch_ec2:
        name: Launch EC2
        runs-on: ubuntu-latest
        defaults:
            run:
              working-directory: terraform
        steps:

            # Step 1 - Checkout Repository
            - name: Checkout Repository
              uses: actions/checkout@v4

            # Step 2 - Install terraform '1.9.8'
            - name: Terraform Workflow
              uses: hashicorp/setup-terraform@v3
              with:
                terraform_version: "1.9.8"
                cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}     # API_TOKEN for HCP Terrafom

            # Step 3 - Terraform init
            - name: Terraform Init
              id: init
              run: terraform init

            # Step 4 - Terraform plan
            - name: Terraform Plan
              id: plan
              run: terraform plan -var "custom_ami_version=${{ inputs.ami_version }}" -no-color
              continue-on-error: true

            # Step 5 - Terraform apply, set variable ami_version
            - name: Terraform Apply
              id: Apply
              run: terraform apply -var "custom_ami_version=${{ inputs.ami_version }}" -auto-approve

            # Step 6 - GiHub step summary
            - name: Step Summary
              run: |
                echo URL="http://$(terraform output ec2_public_ip | tr -d '""')" >> $GITHUB_STEP_SUMMARY
```

{{< admonition >}}
The terraform code for ec2 looks easy on the eyes. The custom AMI needs to be imported first. The instance requires an ingress security rule to allow inbound HTTP traffic.
{{< /admonition >}}

```terraform
# Imports private-ami
data "aws_ami" "custom_ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["devopsify-engineering-${var.custom_ami_version}"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Retrieves vpc and subnet ids from network workspace
data "tfe_outputs" "network" {
  organization = "ajcloudlab"
  workspace    = "network"
}

# Creates an ec2 instance using the imported AMI
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.custom_ami.id
  instance_type               = "t2.micro"
  availability_zone           = var.az
  subnet_id                   = data.tfe_outputs.network.values.public_subnet[1]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_http.id]
  iam_instance_profile        = aws_iam_instance_profile.connectEC2_profile.name

  tags = merge(local.tags,
    {
      Name = var.ec2_name
  })
}

# Creates security group
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic and all outbound traffic"
  vpc_id      = data.tfe_outputs.network.values.vpc

  tags = merge(local.tags,
    {
      Name = var.sg_name
  })
}

# Creates an inbound rule to allow http
resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# Creates an outboud rule to allow all traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
```

### Workflow Trigger

{{< figure src="/images/github_manual%20trigger_input.PNG" title="Figure6: ec2.yaml" >}}

{{< figure src="/images/ec2.PNG" title="Figure7: EC2 instance" >}}

### Browse Application

Go to `http://ec2publicip`


{{< figure src="/images/website.PNG" title="Figure8: website" >}}

**Hurray, the MVP is up and running**










