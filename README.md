# CoffeeNet Dockerized

This projects provides all necessary information about the  
CoffeeNet structure and the services for an easy startup.

When you run the `docker-compose.yml` file as describes below  
a complete CoffeeNet system will be provided that consists of:

The **Core** of the CoffeeNet:
- CoffeeNet Auth Server (http://localhost:9999)
- Coffeenet Discovery Server (http://localhost:8761)
- Coffeenet Config Server (http://localhost:8888)

Optional **Central** Services of the CoffeeNet:  
For additional centralized _logging_ we use graylog, that plays together with  
the [CoffeeNet Starter Logging](https://github.com/coffeenet/coffeenet-starter/tree/master/coffeenet-starter-logging)
- Graylog (http://localhost:9000 - admin/admin)


**Applications** of the CoffeeNet to enrich the functionality:
- [CoffeeNet Frontpage](https://github.com/coffeenet/coffeenet-frontpage) (http://localhost:8081)
- ... or any other application that you developed with the [CoffeeNet Starters](https://github.com/coffeenet/coffeenet-starter/)

If everything started correctly you will have a fully integrated CoffeeNet environment with the following users:

| User | Username | Password | Roles |
|---|---|---|---|
| admin | admin | admin | COFFEENET-ADMIN & USER |
| user | user | user | USER |

and 2000 users for load tests e.g. with the credentials user{1..2000}/user{1..2000} 
(e.g. user1/user1, user2/user2,...) without a role defined.


![CoffeeNetArchitecture][architecture]


## Requirements

* Java 8
* Docker 17.12.0+
* Docker Compose 1.21.x

## Usage with docker-compose

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

## LDAP browser/editor

### Apache Directory Manager

#### macOS

Install Apache Directory Manager (for example with Homebrew)
```bash
brew install Caskroom/cask/apache-directory-studio
```

#### Linux

Download and start the [Apache Directory Manager](http://directory.apache.org/studio/download/download-linux.html)


[architecture]: architecture.png "CoffeeNet Architecture"
