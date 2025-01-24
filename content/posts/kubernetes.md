---
title: 'CloudTalents Application on K8s'
date: 2024-12-05
tags: ["Kubernetes", "Docker", "Python", "nginx"]
categories: ["DevOps"]
---

In the previous post, we used docker-compose to build and manage our multi-container application. Today, I talk about orchestrating those containers using Kubernetes.<!--more-->

fter building the docker image in the [previous article](https://www.devopsifyengineering.com/docker/), it's time to orchestrate containers using K8s. 

Follow along by cloning the below repo.

### Source code repo
{{< admonition info>}}
K8s manifest files are available at [cloudtalents-startup-v1](https://github.com/anoopjayadharan/cloudtalents-startup-v1/tree/main/kubernetes)
{{< /admonition >}}

### Docker Hub

{{< admonition >}}
    The docker image is tagged and pushed to the docker hub.
    {{< /admonition >}}

{{< figure src="/images/dockerhub-images.PNG" title="Figure1: Docker Hub" >}}


### Config Maps and Secrets
When we ran the Django(`app`) container locally, we passed the env file into the docker run to inject configuration variables into the runtime environment. On Kubernetes, configuration variables can be injected using [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) and [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/).

ConfigMaps should be used to store non-confidential configuration information, such as app settings, and Secrets should be used for sensitive information, such as API keys and database credentials.

{{< admonition >}}
We’ve extracted the non-sensitive configuration from the .env.app file and pasted it into a ConfigMap manifest. The ConfigMap object is called app-config.

{{< /admonition >}}

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
    SQL_ENGINE: "django.db.backends.postgresql"
    DATABASE: "postgres"
```

### Setting Up the Postgres Secret
We’ll use the env file from the [docker](https://www.linkedin.com/pulse/dockerizing-cloudtalents-startup-app-anoop-jayadharan-vskaf/?trackingId=pFcG%2FfcPTbu3eRvpP0cA7A%3D%3D) section, removing variables inserted into the ConfigMap.

Create a file `db-secrets` and load the values as follows.

```bash
POSTGRES_USER=<FILL_HERE>
POSTGRES_PASSWORD=<FILL_HERE>
POSTGRES_DB=mvp
```
{{< admonition info>}}
Now, create the secret using the following command

{{< /admonition >}}

```
kubectl create secret generic postgres-secret  --from-env-file=db-secrets
```
### Rolling out the Postgres DB using a StatefulSet
The first step is to deploy Postgres as a stateful set with a headless service. A stateful set is a Kubernetes resource that manages deploying and scaling a set of Pods with persistent identities and storage. A headless service is a Kubernetes service that does not have a cluster IP address. Instead, it provides DNS records for the pods in the stateful set.

{{< admonition tip>}}
A stateful set requires dynamic volume provisioning, which is met by installing [rancher](https://github.com/rancher/local-path-provisioner?tab=readme-ov-file) local path provisioner. 
{{< /admonition >}}

{{< figure src="/images/rancher.PNG" title="Figure2: local-path provisioner" >}}

The following YAML file defines a headless service named db that exposes port `5432` and selects Pods with the label app: postgres. It also defines a stateful set named "postgres" that uses the headless service, has one replica, and creates Pods with the label app: postgres. Each Pod has a container named Postgres that runs the image `postgres:16`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db
  labels:
    app: postgres
spec:
  ports:
    - port: 5432
  selector:
    app: postgres
  clusterIP: None
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: db
          image: 'postgres:16'
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5432
          envFrom:
            - secretRef:
                name: postgres-secret
          volumeMounts:
            - mountPath: /var/lib/postgresql/data
              name: postgresdata
  volumeClaimTemplates:
      - metadata:
          name: postgresdata
        spec:
          accessModes:
            - ReadWriteOnce
          storageClassName: "local-path"
          resources:
            requests:
              storage: 512Mi

```
Then, you can apply the YAML file by running

```
kubectl apply -f postgres-sts.yaml
```

{{< admonition info>}}
The command above will create the headless service and the stateful set in your cluster. You can verify them by running the following commands:

```
k get pv
k get pvc -l app=postgres
k get svc -l app=postgres
k get po -l app=postgres
```
{{< /admonition >}}

### Output - DB
{{< figure src="/images/postgres-pod.PNG" title="Figure3: statefulset-postgress" >}}

{{< admonition >}}
The local-path provisioner mounts a directory /opt/local-path-provisioner on the node to which the db pod gets assigned.

{{< figure src="/images/mount.PNG" title="Figure4: directory mount" >}}
{{< /admonition >}}

### Rolling out the Django app using a Deployment

In this step, we will create a Deployment for your Django app. A Kubernetes Deployment is a controller that can manage stateless applications in your cluster. A controller is a control loop that regulates workloads by scaling them up or down. Controllers also restart and clear out failed containers.

Here, we define a Kubernetes Deployment called app and label it with the key-value pair name: app. We specify that we’d like to run only one replica of the Pod defined below the template field.

```yaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  labels:
    app: app
  name: app
spec:
  ports:
  - name: "8000"
    port: 8000
    protocol: TCP
    targetPort: 8000
  selector:
    name: app
  type: ClusterIP
status:
  loadBalancer: {}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: django
  name: app
spec:
  replicas: 1
  selector:
    matchLabels:
      name: app
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        name: app
    spec:
      containers:
      - image: ajdemo/cloudtalents-startup-app:v1
        imagePullPolicy: Always
        name: app
        command: ["/opt/app/web/entrypoint.sh"]
        args: ["gunicorn" , "--bind","0.0.0.0:8000", "cloudtalents.wsgi:application"]
        envFrom:
          - secretRef:
              name: app-secret
          - configMapRef:
              name: app-config
        ports:
          - containerPort: 8000
             name: gunicorn
        volumeMounts:
          - mountPath: /opt/app/web/media/
            name: media-volume
      volumes:
          - name: media-volume
            hostPath:
                path: /media/images # directory location on host
                type: DirectoryOrCreate # this field is optional
status: {}
```
Using `envFrom` with `secretRef` and `configMapRef`, we specify that all the data from the app-secret Secret and app-config ConfigMap should be injected into the containers as environment variables. The ConfigMap and Secret keys become the environment variable names.

{{< admonition >}}
    Finally, we expose containerPort 8000 and name it gunicorn.
{{< /admonition >}}

**Create the Deployment using `k apply -f app-deploy.yaml`**

{{< admonition info>}}
Verify the resources using the following commands.
```
k get deploy
k get po -l name=app
k get svc -l app=app
```
{{< /admonition >}}

### Output - APP

{{< figure src="/images/app-details.PNG" title="Figure5: deployment-app" >}}

**Now execute the `Django migration` using the command below**
```
k exec -it <app-pod-name> -- python3 manage.py migrate
```
Migrations are Django’s way of propagating changes you make to your models (adding a field, deleting a model, etc.) into your database schema. Successful execution of the command returns the below output. 

{{< figure src="/images/migration.PNG" title="Figure6: deployment-app" >}}

### Rolling out the NGINX using a Deployment

In this step, we will create a Deployment for your nginx. It first creates a ConfigMap and uses a custom nginx.conf file. It is mounted as a volume inside `/etc/nginx/conf.d` directory of Pod. 

A `nodePort` service exposes the Pod to the outside world.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
data:
  nginx.conf: |
    upstream cloudtalents {
      server app:8000;
    }

    server {

    listen 80;

    location / {
        proxy_pass http://cloudtalents;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_redirect off;
      }

    location /media/ {
        alias /opt/app/web/media/;
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: nginx
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:1.25
        name: nginx
        volumeMounts:
          - mountPath: /opt/app/web/media/
            name: media-volume
          - name: nginx-conf
            mountPath: /etc/nginx/conf.d
      volumes:
        - name: nginx-conf
          configMap:
            name: nginx-conf
            items:
              - key: nginx.conf
                path: nginx.conf
        - name: media-volume
          hostPath:
            path: /media/images
            type: DirectoryOrCreate

status: {}
---
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  labels:
    app: nginx
  name: nginx
spec:
  ports:
  - name: web
    nodePort: 31680
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
  type: NodePort
status:
  loadBalancer: {}
```
**Create the deployment using the following command**
```
k apply -f nginx-deploy.yaml
```
Verify the resources using the following command
```
k get all -l app=nginx
```

### Output - NGINX

{{< figure src="/images/nginx-pod.PNG" title="Figure7: deployment-nginx" >}}

Access the application through a browser and upload an image.

You can use either the k8s master or worker IP address and port `31680` to access the app.

{{< figure src="/images/k8s-website.PNG" title="Figure8: application" >}}

{{< admonition tip>}}
The setup can be improved by deploying an ingress controller to leverage L7 routing based on the URI.
{{< /admonition >}}

I have deployed the [NGINX ingress controller](https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-manifests/) by following the steps from the official documentation.

Create an ingress resource using the YAML file below

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: "cloudtalentstartup.com"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: nginx
            port:
              number: 80
```
{{< admonition >}}
    An Ingress resource will be created and will look like the one below

{{< figure src="/images/ing.PNG" title="Figure9: Ingress resource" >}}
{{< /admonition >}}

{{< admonition tip>}}
One final modification is needed: change the node port for the nginx-ingress service to `31780`


{{< figure src="/images/nodeport.PNG" title="Figure10: ingress nodeport-svc" >}}
{{< /admonition >}}

### Rollout 

Now access the app using the FQDN `http://cloudtalentstartup.com:31780`

{{< figure src="/images/cloudtalents-website.PNG" title="Figure11: website-final-version" >}}

{{< admonition >}}

    Now the application can be scaled up seamlessly to meet the high volume of traffic

{{< /admonition >}}



















