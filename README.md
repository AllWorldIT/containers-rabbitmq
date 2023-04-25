[![pipeline status](https://gitlab.conarx.tech/containers/rabbitmq/badges/main/pipeline.svg)](https://gitlab.conarx.tech/containers/rabbitmq/-/commits/main)

# Container Information

[Container Source](https://gitlab.conarx.tech/containers/rabbitmq) - [GitHub Mirror](https://github.com/AllWorldIT/containers-rabbitmq)

This is the Conarx Containers RabbitMQ image, it provides the RabbitMQ message broker server.



# Mirrors

|  Provider  |  Repository                              |
|------------|------------------------------------------|
| DockerHub  | allworldit/rabbitmq                      |
| Conarx     | registry.conarx.tech/containers/rabbitmq |



# Conarx Containers

All our Docker images are part of our Conarx Containers product line. Images are generally based on Alpine Linux and track the
Alpine Linux major and minor version in the format of `vXX.YY`.

Images built from source track both the Alpine Linux major and minor versions in addition to the main software component being
built in the format of `vXX.YY-AA.BB`, where `AA.BB` is the main software component version.

Our images are built using our Flexible Docker Containers framework which includes the below features...

- Flexible container initialization and startup
- Integrated unit testing
- Advanced multi-service health checks
- Native IPv6 support for all containers
- Debugging options



# Community Support

Please use the project [Issue Tracker](https://gitlab.conarx.tech/containers/rabbitmq/-/issues).



# Commercial Support

Commercial support for all our Docker images is available from [Conarx](https://conarx.tech).

We also provide consulting services to create and maintain Docker images to meet your exact needs.



# Environment Variables

Additional environment variables are available from...
* [Conarx Containers Alpine image](https://gitlab.conarx.tech/containers/alpine)


## RABBITMQ_NODENAME

RabbitMQ node name, defaults to `rabbitmq`.


## RABBITMQ_ADMIN_USERNAME

RabbitMQ admin username, defaults to `rabbitmqadmin`. This user is only created if the associated password below is set.


## RABBITMQ_ADMIN_PASSWORD

RabbitMQ admin password.


## RABBITMQ_USERNAME

RabbitMQ user to create for read/write (non configuration) access. If unset, no user will be created.


## RABBITMQ_PASSWORD

RabbitMQ user password for `RABBITMQ_USERNAME`.


## RABBITMQ_*

All environment variable starting with `RABBITMQ_` are dumped to `/etc/rabbitmq/rabbitmq-env.conf`.

ref: https://www.rabbitmq.com/configure.html#customise-environment


# Volumes


## /var/lib/rabbitmq

RabbitMQ data directory.



# Files


## /etc/rabbitmq/definitions.d/50-fdc-init.json

Definition file created during startup. If it exists it will not be overwritten.



# Exposed Ports

|  Port   |  Description                                                     |
|---------|------------------------------------------------------------------|
|  4369   | EPMD peer discovery service                                      |
|  5671   | AMQP clients with TLS                                            |
|  5672   | AMQP clients without TLS                                         |
|  15671  | HTTP API with TLS                                                |
|  15672  | HTTP API without TLS                                             |
|  15692  | Prometheus metrics with TLS (if Prometheus plugin is enabled)    |
|  15692  | Prometheus metrics without TLS (if Prometheus plugin is enabled) |
|  25672  | Inter-node and CLI communication                                 |


# Configuration Exampmle


```yaml
version: '3.9'

services:
  minio:
    image: registry.gitlab.iitsp.com/allworldit/docker/rabbitmq
    environment:
      - RABBITMQ_ADMIN_USERNAME=myadmin
      - RABBITMQ_ADMIN_PASSWORD=myadmin
    volumes:
      - ./data:/var/lib/rabbitmq
    ports:
      - '5672:5672'
      - '15672:15672'
    networks:
      - internal

networks:
  internal:
    driver: bridge
    enable_ipv6: true
```