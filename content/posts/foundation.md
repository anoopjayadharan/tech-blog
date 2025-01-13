---
title: 'AWS Landing Zone using Control Tower'
date: 2024-10-21
draft: false
tags: ["AWS", "devOps", "controltower"]
categories: ["DevOps"]
---
Companies that follow the AWS Security Reference Architecture will have multiple accounts for various teams or divisions. As a Cloud/DevOps engineer, you are responsible for managing those accounts. <!--more-->

{{< figure src="/images/control%20tower.PNG" title="Figure1: Landing zone Overview" >}}


### Landing Zone
Recently, I set up a landing zone on AWS using the control tower. A landing zone is a well-architected, multi-account, scalable, and secure AWS environment. It is a starting point from which your organization can quickly launch and deploy workloads and applications confidently in your security and infrastructure environment.

{{< figure src="/images/landing%20zone%20settings.PNG" title="Figure2: Settings" >}}


{{< admonition >}}
The account on which you deploy the AWS control tower will become the Management account. Two additional accounts, one for LogArchive and another for Audit, are to be created.
{{< /admonition >}}

### Control Tower
AWS Control Tower automates the setup of a new landing zone by using best practices, blueprints for identity, federated access, and account structure. Some of the blueprints implemented on AWS Control Tower include:

- A multi-account environment using AWS Organizations

{{< figure src="/images/control%20tower_org.png" title="Figure3: AWS Organization" >}}

- Cross-account security audits using AWS Identity and Access Management (IAM) and AWS IAM Identity Center
{{< figure src="/images/user%20access%20portal.png" title="Figure4: User Access Portal" >}}

- Identity management using the Identity Center default directory
- Centralized logging from AWS CloudTrail and AWS Config stored in Amazon Simple Storage Service (Amazon S3)

{{< admonition >}}
    In addition, an IAM user with admin privilege is created on the IAM Identity Center to manage user access to AWS accounts centrally.
{{< /admonition >}}

### AWS Config
AWS Config provides a detailed view of the configuration of AWS resources in your AWS account. This includes how the resources are related to one another and how they were configured in the past so that you can see how the configurations and relationships change over time.
{{< figure src="/images/AWS%20Config.PNG" title="Figure5: AWS Config" >}}

