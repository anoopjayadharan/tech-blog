---
title: 'Dockerizing Cloudtalents Startup App'
date: 2024-11-27
tags: ["Docker", "Python",  "nginx", "Gunicorn"]
categories: ["DevOps"]
---

Ever since the MVP was up and running, I could not stop building the Django application's docker image knowing the containerization fundamentals.<!--more-->

Experimenting with various aspects of the docker container in the local machine was entertaining.

Reading my previous [article](https://www.devopsifyengineering.com/launching-mvp/) will help you learn about the cloud talents application we will containerize.


All right, here you go; this is the high-level overview of the application.

- It is written in Python and uses the Django web framework.
- NGINX serves as a reverse proxy
- Gunicorn implements the web server gateway interface(WSGI), translating HTTP requests into something Python can understand
- Postgres is the chosen database for storing the authenticated user data.

We have chosen to run three containers: one for `NGINX`, one for the business logic `(Django + Gunicorn)`, and the last for `Postgres`. 

### Source code repo
{{< admonition info>}}
The Source code is available at [cloudtalents-startup-v1](https://github.com/anoopjayadharan/cloudtalents-startup-v1)

{{< /admonition >}}


However, the following changes were made to the `settings.py` file under the `cloudtalents` directory.

```python
import os

SECRET_KEY = os.environ.get("SECRET_KEY")

DATABASES = {
    'default': {
        "ENGINE": os.environ.get("SQL_ENGINE"),
        "NAME": os.environ.get("SQL_DATABASE"),
        "USER": os.environ.get("SQL_USER"),
        "PASSWORD": os.environ.get("SQL_PASSWORD"),
        "HOST": os.environ.get("SQL_HOST"),
        "PORT": os.environ.get("SQL_PORT"),

    }
} 
```

Variables are loaded into the docker using the env file `.env.app`

```bash
SECRET_KEY=<FILL_HERE>
SQL_ENGINE=django.db.backends.postgresql
SQL_DATABASE=mvp
SQL_USER=<FILL_HERE>
SQL_PASSWORD=<FILL_HERE>
SQL_HOST=db
SQL_PORT=5432
DATABASE=postgres
```

Postgres requires environment variables such as username, password, and database details to initialize the database. So, another file`(.env.db)` with the following information is out there.

```bash
POSTGRES_USER=<FILL_HERE>
POSTGRES_PASSWORD=<FILL_HERE>
POSTGRES_DB=mvp
```
### Dockerfile
Now, let us write the `Dockerfile` for the business logic(Django + unicorn). We will use a multi-stage builder approach with python:3.11.4-slim-buster as the parent image. In the `builder` section, dependencies and flakes are installed. The `flake` is a command-line utility that checks Python code against coding style (PEP 8), programming errors, and complex constructs.

```dockerfile
###########
# BUILDER #
###########

# pull official base image
FROM python:3.11.4-slim-buster as builder

# set work directory
WORKDIR /usr/src/app

# set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc

# lint
RUN pip install --upgrade pip
RUN pip install flake8==6.0.0
COPY . /usr/src/app/
RUN flake8 --ignore=E501,F401 .

# install python dependencies
COPY ./requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt


#########
# FINAL #
#########

# pull official base image
FROM python:3.11.4-slim-buster

# create directory for the app user
RUN mkdir -p /opt/app

# create the app user
RUN addgroup --system app && adduser --system --group app

# create the appropriate directories
ENV HOME=/opt/app
ENV APP_HOME=/opt/app/web
RUN mkdir $APP_HOME
RUN mkdir $APP_HOME/staticfiles
RUN mkdir $APP_HOME/mediafiles
WORKDIR $APP_HOME

# install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends netcat
COPY --from=builder /usr/src/app/wheels /wheels
COPY --from=builder /usr/src/app/requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache /wheels/*

# copy entrypoint.prod.sh
COPY ./entrypoint.sh .
RUN sed -i 's/\r$//g'  $APP_HOME/entrypoint.sh
RUN chmod +x  $APP_HOME/entrypoint.sh

# copy project
COPY . $APP_HOME

# chown all the files to the app user
RUN chown -R app:app $APP_HOME

# change to the app user
USER app

# run entrypoint.sh
ENTRYPOINT ["/opt/app/web/entrypoint.sh"]
```
In the FINAL section of the build stage, an app user and its home directories are created. A couple of directories are made to store static and media files. The media files will be served from NGINX, which we will see later. A script named `entrypoint.sh` will run as the docker entry point. This script checks for the `db` container before starting the app.

```bash
#!/bin/sh

if [ "$DATABASE" = "postgres" ]
then
    echo "Waiting for postgres..."

    while ! nc -z $SQL_HOST $SQL_PORT; do
      sleep 0.1
    done

    echo "PostgreSQL started"
fi

exec "$@"
```

### NGINX
It is a simple Dockerfile to the standards. To reduce the attack surface, the user is set to `nginx` instead of root. The parent image is chosen as nginx:1.27.

The nginx user requires permission to access a few directories to function correctly. 

```dockerfile
FROM nginx:1.27

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d

RUN mkdir -p /var/cache/nginx/client_temp && \
        mkdir -p /var/cache/nginx/proxy_temp && \
        mkdir -p /var/cache/nginx/fastcgi_temp && \
        mkdir -p /var/cache/nginx/uwsgi_temp && \
        mkdir -p /var/cache/nginx/scgi_temp && \
        chown -R nginx:nginx /var/cache/nginx && \
        chown -R nginx:nginx /etc/nginx/ && \
        chmod -R 755 /etc/nginx/ && \
        chown -R nginx:nginx /var/log/nginx

RUN touch /var/run/nginx.pid && \
        chown -R nginx:nginx /var/run/nginx.pid /run/nginx.pid

USER nginx

CMD ["nginx", "-g", "daemon off;"]
```

All we do differently is use a custom nginx.conf file as below. The requests are proxied to the app containers. The media files are stored at `/opt/app/web/media`.

```
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
```

### Docker Compose
Now, let us build our docker-compose file. Two volume directories are defined, one for Postgres and the other for media. The media_volume is attached to both NGINX and WEB services. 

it builds Docker images for web and nginx services using the above Dockerfiles.

```yaml
services:
  nginx:
    build: ./nginx
    container_name: nginx
    volumes:
      - media_volume:/opt/app/web/media
    ports:
     - 80:80
    depends_on:
     - web
  web:
    build:
      context: ./app
      dockerfile: Dockerfile
    container_name: app
    volumes:
      - media_volume:/opt/app/web/media
    command: gunicorn cloudtalents.wsgi:application --bind 0.0.0.0:8000
    expose:
      - 8000
    env_file:
      - ./.env.app
    depends_on:
      - db
  db:
    image: postgres:16
    container_name: db
    volumes:
      - postgres_data:/var/lib/postgresql/data/
    env_file:
      - ./.env.db

volumes:
  postgres_data:
  media_volume:

```

The `app` container starts following the DB. The env files are being passed to the respective containers.

{{< figure src="/images/docker-compose%20up.PNG" title="Figure1: Docker compose" >}}

### List containers

{{< figure src="/images/docker-compose%20ps.PNG" title="Figure2: container list" >}}

{{< admonition >}}
    Well, the containers are up and running. Let us examine the docker volumes.
{{< /admonition >}}

### Docker Volumes

{{< figure src="/images/docker%20volumes.PNG" title="Figure3: docker volumes" >}}



{{< admonition tip>}}

Next, we need to apply the Django changes to create the sessions on the database.

{{< /admonition >}}

{{< figure src="/images/py%20migrate-%20anoop.PNG" title="Figure4: django migrate" >}}

Significant, no errors. Now, let us try to access the application and upload an image.

### Browse the application

{{< figure src="/images/web.PNG" title="Figure5: App" >}}

### Observability

Let's look at the docker-compose logs to understand the flow. Nginx serves as a reverse proxy, sending requests to the app container upstream. The app retries the user details from the db before constructing the HTML page. 



{{< figure src="/images/docker-compose%20logs.PNG" title="Figure6: logs" >}}

If you'd like to see the database tables, please refer to the following diagram. In the `startup_image` table, the image name is `DevOps`, and the description is `Overview`. The details match the figure above. 

{{< figure src="/images/db%20tables.PNG" title="Figure7: postgres db" >}}




