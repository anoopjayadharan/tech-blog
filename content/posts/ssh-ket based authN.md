---
title: 'SSH-Key Based AuthN Github'
date: 2024-10-25
draft: false
tags: ["GitHub", "SSH", "AuthN"]
categories: ["Documentation"]
---
How about managing multiple GitHub accounts locally using SSH Keys?

In the real world, you must work with multiple GitHub accounts: one for open-source contributions, another for personal projects, and probably one more for your corporate tasks.

{{< admonition >}}
    The following diagram illustrates the setup
{{< /admonition >}}

![](/images/ssh-key%20authn-Diagram.PNG)

### Watch me demontrate the task over a video **[HERE](https://www.loom.com/share/06c3fc273ff24547a94135f623e557be?sid=8522f7ed-a3fc-405e-a437-44b9b149eb63)**

{{< admonition tip>}}
The commands being used in the video are as follows;

{{< /admonition >}}

```bash
ssh-keygen -t ed25519 -C "youremail" -f "<github-username>"
ssh-keygen -t ed25519 -C "youremail" -f "<github-username>"

#Add keys to SSH Agent:
eval "$(ssh-agent -s)"

ssh-add ~/.ssh/<github-username>
ssh-add ~/.ssh/<github-username>

#SSH Config:

#Personal Account
     Host github.com-<github-username>
          HostName github.com
          User git
          IdentityFile ~/.ssh/<github-username>

#New Account
       Host github.com-<github-username>
            HostName github.com
            User git
            IdentityFile ~/.ssh/<github-username>
			
			
#Test SSH Connectivity:

#First Account:
ssh -T git@github.com-<github-username>

#Second Account:
ssh -T git@github.com-<github-username>

#Set Remote Origin:

github.com-<github-username>:<github-username>/<repo>.git

git@github.com-<github-username>:<github-username>/<repo>.git

```



