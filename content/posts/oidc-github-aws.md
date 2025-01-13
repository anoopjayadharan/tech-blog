---
title: 'OIDC Integration between GitHub and AWS'
date: 2024-10-29
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
{{< figure src="/images/Github%20OIDC%20with%20AWS.png" title="Figure1: OIDC Integration between GitHub and AWS" >}}


### Action Items
- Configure GitHub as an OIDC provider in AWS
{{< figure src="/images/IDP_AWS.png" title="Figure2: OIDC Provider" >}}

- Create an IAM policy; here, I give an example of  uploading objects to my s3 bucket.

    {{< figure src="/images/IAM%20Policy.PNG" title="Figure3: IAM Policy" >}}


- Create an IAM Role of type web Identity. To create a trust policy, you must provide details like GitHub organization, repository(optional) and branch(optional).

    {{< figure src="/images/IAM_Role.png" title="Figure4: IAM Role" >}}


- Copy the Role ARN and create it as a GitHub secret.

{{< admonition tip>}}
    Once you've done this, use this official action from the GitHub marketplace: https://github.com/marketplace/actions/configure-aws-credentials-action-for-github-actions. This action uses tokens to authenticate to AWS and access resources.
{{< /admonition >}}

### OIDC Flow

Last, every time a job runs, GitHub's OIDC Provider auto-generates an OIDC token. The job requires a  permissions setting with id-token: write to allow GitHub's OIDC provider to create a JSON Web Token for every run.

{{< figure src="/images/OIDC.PNG" title="Figure5: OIDC Flow" >}}
1. In your cloud provider, create an OIDC trust between your cloud role and your GitHub workflow(s) that need access to the cloud.

2. Every time your job runs, GitHub's OIDC Provider auto-generates an OIDC token. This token contains multiple claims to establish a security-hardened and verifiable identity about the specific workflow that is trying to authenticate.

3. You could include a step or action in your job to request this token from GitHub's OIDC provider, and present it to the cloud provider.

4. Once the cloud provider successfully validates the claims presented in the token, it then provides a short-lived cloud access token that is available only for the duration of the job.

{{< admonition tip>}}
A sample workflow is supplied at https://gist.github.com/anoopjayadharan-me/c7485ed9264f64ef3edbc2dc069e139e.

{{< /admonition >}}
{{< figure src="/images/OIDC%20workflow.PNG" title="Figure6: gist" >}}


### Reference

- [About security hardening with OpenID Connect](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

- [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

- [Configure AWS Credentials for GitHub Actions](https://github.com/aws-actions/configure-aws-credentials#configure-aws-credentials-for-github-actions)