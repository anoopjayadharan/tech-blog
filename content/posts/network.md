---
title: 'Networking in AWS'
date: 2024-10-18
tags: ["AWS", "VPC", "Terraform", "RAM"]
categories: ["Documentation"]
draft: false
---

Networking is one of the core pillars of the cloud computing model. Amazon VPC(virtual private cloud) helps you launch a secure, isolated private cloud hosted within a public cloud.

In a multi-account environment, you must find a way to create VPCs and associated objects across managed accounts. AWS recommends creating a Network account under the Infrastructure OU.

### AWS SRA Infrastructure OU - Network Account
[AWS Security Reference Architecture](https://lnkd.in/dYvqm8Y5) states that the Network account is the gateway between your apps and the Internet. Network resources are defined at one account, and then, leveraging another managed service called RAM(Resource Access Manager), these resources can be shared with accounts in the organization or only with the accounts within one or more specified organizational units (OUs).

{{< figure src="/images/AWS%20SRA.PNG" title="AWS Security Reference Architecture" >}}


### GitHub Repository
The source code can be found **[HERE](https://github.com/anoopjayadharan/network)**

### Building the Connectivity
In one of the blogs, I talk about setting up an [AWS landing zone](https://www.linkedin.com/pulse/aws-landing-zone-anoop-jayadharan-oqg5f?trk=public_post_feed-article-content) using the control tower.

Followed these steps from the control tower section of the Management account

- Create an OU named `Infrastructure`

{{< figure src="/images/OU%20List.png" title="Infrastructure-OU" >}}


- Create an AWS account named `Network` from the account factory.

{{< figure src="/images/Network%20Account.png" title="Network Account" >}}


- Disable automatic creation of VPCs in all regions by the Account Factory in AWS Control Tower.

{{< figure src="/images/Disable%20VPC%20Creation.png" title="Network Configuration" >}}


{{< admonition >}}
Now that our network account is ready, we must deploy a VPC resource using [Terraform](https://github.com/anoopjayadharan/network) via the [GitHub Actions workflow](https://github.com/anoopjayadharan/network/blob/main/.github/workflows/network.yml). 
{{< /admonition >}}

In another post, I discussed the steps to integrate [GitHub with AWS using OIDC](https://www.linkedin.com/pulse/oidc-integration-between-github-aws-anoop-jayadharan-ys2uf/?trackingId=69sxrTdmRiiz%2BJQ%2FRjvI%2Bw%3D%3D). In the same way, HCP Terraform must also be integrated with AWS for infrastructure provisioning. Add HCP as the OIDC provider on the AWS and create an IAM role. This role must be added as a variable on your HCP workspace/organization. 

{{< figure src="/images/HCP%20variable%20set.PNG" title="HCP Variables" >}}


### Virtual Private Cloud(VPC)
Our new VPC contains the following resources:

- Two public subnets
- Two private subnets
- One internet gateway
- Four routing tables

{{< figure src="/images/building%20network.jpg" title="VPC Overview" >}}


{{< admonition >}}
`A successful workflow summary will look like this`
{{< /admonition >}}
{{< figure src="/images/workflow%20summary.PNG" title="Workflow Summary" >}}

### Network Account
Connect to the **Network** account and verify the VPC creation.

{{< figure src="/images/vpc%20resource%20map.PNG" title="VPC Resources" >}}

### Resource Access Manager(RAM)
The last step is to create a resource share using AWS Resource Access Manager(RAM) to share all four VPC subnets with the "Sandbox" OU.
{{< figure src="/images/RAM%20Diagram.PNG" title="Resource Access Manager" >}}

{{< admonition >}}
Our terraform code contains a file named `ram.tf` as follows
{{< /admonition >}}

```terraform
# Creates a Resource Access Manager (RAM) Resource Share
resource "aws_ram_resource_share" "subnet_share" {
  name = var.ram_name
  tags = local.tags
}

# Associates Private Subnets to RAM
resource "aws_ram_resource_association" "private_subnets" {
  count              = length(var.private_subnet_cidr)
  resource_arn       = aws_subnet.private[count.index].arn
  resource_share_arn = aws_ram_resource_share.subnet_share.arn
}

# Associates Public Subnets to RAM
resource "aws_ram_resource_association" "public_subnets" {
  count              = length(var.public_subnet_cidr)
  resource_arn       = aws_subnet.public[count.index].arn
  resource_share_arn = aws_ram_resource_share.subnet_share.arn
}

# Share resources to Sandbox OU
resource "aws_ram_principal_association" "ram_principal_association" {
  principal          = var.ou_arn
  resource_share_arn = aws_ram_resource_share.subnet_share.arn
}
```
{{< admonition tip>}}
One quick tip is to add the `ARN of Sandbox OU` to the Terraform workspace.

{{< figure src="/images/workspace%20variable.PNG" title="Workspace Variable" >}}

{{< /admonition >}}

Resource share has been created and will look like the one below. Notice "shared by me", ie, the Network Account

{{< figure src="/images/Resource%20share.PNG" title="Resource Share-by me" >}}

### Development Account
Connect to the "development" account, and you will see "shared with me" under RAM.

{{< figure src="/images/shared%20with%20me.PNG" title="Resource Shared-with me" >}}

In this way, all future accounts within **Sandbox OU** will inherit the shared VPC from the Network account. 

### Reference{#reference}

- [AWS SRA](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/network.html)

- [RAM](https://docs.aws.amazon.com/ram/latest/userguide/getting-started-sharing.html#getting-started-sharing-orgs)