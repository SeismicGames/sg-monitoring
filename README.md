# sg-monitoring

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with monitoring](#setup)
    * [What is installed](#what-is-installed)
    * [Parameters](#parameters)
    * [Beginning with monitoring](#beginning-with-monitoring)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

This Puppet module builds a complete monitoring/stats solution on a single machine.

This module requires [sg-uwsgi] (https://github.com/SeismicGames/sg-uwsgi) to be in
your Puppet modules location.

## Module Description

There are a lot of Puppet modules out there for individual pieces to build a 
monitoring and stats system, but there wasn't one that builds a complete solution.
This Puppet module does that. 

## Setup

To use:

```
class { 'monitoring':
  env => 'local', 
  domain => 'localhost' 
}
```

### What is installed

* RabbitMQ
* Npm
* Memcached (for Graphite)
* Redis
* Nginx (for proxying the multiple web endpoints) 
* Postgesql
* StatsD
* Graphite
* Grafana
* Sensu
* Uchiwa

### Parameters

| Name | Purpose | Default | Optional/Required |
| --- | --- | --- | --- |
| env                      | Environment label | | Required |
| domain                   | Domain to use for Nginx config | | Required |
| postgresql_pass          | Postgresql superuser password | `postgres` | |
| sensu_rabbitmq_user      | RabbitMQ user for Sensu | `sensu` | |
| sensu_rabbitmq_pass      | RabbitMQ password for Sensu | `sensu`    | Optional |
| graphite_sql_user        | Graphite Postgresql user | `graphite` | Optional |
| graphite_sql_pass        | Graphite Postgresql password | `graphite` | Optional |
| grafana_sql_user         | Grafana Postgresql user | `grafana`  | Optional |
| grafana_sql_pass         | Grafana Postgresql password | `grafana`  | Optional |
| grafana_admin_user       | Grafana admin user | `admin`    | Optional |
| grafana_admin_pass       | Grafana admin password | `admin`    | Optional |
| memcached_max_memory     | Memcached max memory setting | `20%`      | Optional |
| graphite_secret_key      | Graphite secret key | undef      | Optional |
| sensu_api_user           | Sensu API user | `sensu`    | Optional |
| sensu_api_pass           | Sensu API user | `sensu`    | Optional |
| email_user               | Sensu alert email user | | Required |
| email_password           | Sensu alert email password | | Required |
| email_server             | Sensu alert email server | | Required |
| email_port               | Sensu alert email server port | | Required |
| email_from               | Sensu alert email from address | | Required |
| email_to                 | Sensu alert email to address | | Required |
| additional_subscriptions | Any additional subscriptions you want to add to the Sensu checks on the server | [] | Optional |
 
### Beginning with monitoring

Everything should just run out of the box. The module also installed Sensu 
monitoring on itself to verify every service is up and running.

* If `env` is set to 'local', the module assumes this is a Vagrant install and will
use the machine IP as the domain instead of the `domain` setting.
* If `graphite_secret_key` is empty a Graphite secret key will automatically be 
generated. 

## Limitations

* The default usernames and passwords are very insecure. This module assumes that 
the monitoring instance is being deployed in a private network.
* Currently only tested on Ubuntu 16.04

## Development

Feel free to use as you wish. If you have any suggestions or improvements please let
us know. 