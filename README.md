# CoffeeNet Dockerized

With the provided docker-compose file you can test the auth server with its needed services very easy.
When you run the docker-compose.yml file as describes below these services will be started:
* CoffeeNet Auth (http://localhost:9999)
* Coffeenet Discovery (http://localhost:8761)
* Coffeenet Config Server (http://localhost:8888)
* Ldap Server (ds-389) (ldap://localhost:38900)
* MariaDb (mariadb://localhost:[3306,3308]/auth - auth/auth)
* Graylog (http://localhost:9000 - admin/admin)

You will have a fully integrated CoffeeNet environment with the following users:

| User | Username | Password | Roles |
|---|---|---|---|
| admin | admin | admin | COFFEENET-ADMIN & USER |
| user | user | user | USER |

and 2000 users for load tests e.g. with the credentials user{1..2000}/user{1..2000} 
(e.g. user1/user1, user2/user2,...) without a role defined.


# Usage with docker-compose

Build the image:

```bash
docker-compose build
```

Start all images

```bash
docker-compose up
```

Or start a specific image

```
docker-compose up ${dockerService}
```

# LDAP browser/editor

## Apache Directory Manager

### macOS

Install Apache Directory Manager (for example with Homebrew)
```bash
brew install Caskroom/cask/apache-directory-studio
```

### Linux

Download and start the Apache Directory Manager from http://directory.apache.org/studio/download/download-linux.html
