---
title: 'OIDC Integration between GitHub and AWS'
date: 2024-10-20
# hiddenFromHomePage: true
tags: ["AWS", "OIDC",  "GitHub"]
categories: ["Documentation"]
draft: false
---

If you think security is paramount, stop using hard-coded cloud provider credentials in your CI/CD pipeline. In this blog, I discuss the steps to integrate GitHub as an OIDC provider in AWS.



Does your GitHub Actions CI/CD pipeline have hard-coded, long-lived cloud-provider credentials for communicating with various cloud services?

Using hardcoded secrets requires creating credentials in the cloud provider and then duplicating them in GitHub as a secret.

On the other hand, OpenID Connect allows your workflows to exchange short-lived tokens directly from your cloud provider.

### How it works
![](/images/Github%20OIDC%20with%20AWS.png)

### Action Items
- Configure GitHub as an OIDC provider in AWS
![](/images/IDP_AWS.png)

- Create an IAM policy; here, I give an example of  uploading objects to my s3 bucket.


    ![](/images/IAM%20Policy.PNG)

- Create an IAM Role of type web Identity. To create a trust policy, you must provide details like GitHub organization, repository(optional) and branch(optional).

    ![](/images/IAM_Role.png)

- Copy the Role ARN and create it as a GitHub secret.

    Once you've done this, use this official action from the GitHub marketplace: https://github.com/marketplace/actions/configure-aws-credentials-action-for-github-actions. This action uses tokens to authenticate to AWS and access resources.

### OIDC Flow

Last, every time a job runs, GitHub's OIDC Provider auto-generates an OIDC token. The job requires a  permissions setting with id-token: write to allow GitHub's OIDC provider to create a JSON Web Token for every run.

![](/images/OIDC%20flow.PNG)

A sample workflow is supplied at https://gist.github.com/anoopjayadharan-me/c7485ed9264f64ef3edbc2dc069e139e.

![](/images/OIDC%20workflow.PNG)

### Reference

- [About security hardening with OpenID Connect](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

- [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

- [Configure AWS Credentials for GitHub Actions](https://github.com/aws-actions/configure-aws-credentials#configure-aws-credentials-for-github-actions)