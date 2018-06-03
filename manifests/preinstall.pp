class monitoring::preinstall {
  $postgresql_pass      = $::monitoring::postgresql_pass
  $sensu_rabbitmq_user  = $::monitoring::sensu_rabbitmq_user
  $sensu_rabbitmq_pass  = $::monitoring::sensu_rabbitmq_pass
  $graphite_sql_user    = $::monitoring::graphite_sql_user
  $graphite_sql_pass    = $::monitoring::graphite_sql_pass
  $grafana_sql_user     = $::monitoring::grafana_sql_user
  $grafana_sql_pass     = $::monitoring::grafana_sql_pass
  $memcached_max_memory = $::monitoring::memcached_max_memory

  # install rabbitmq
  class { 'rabbitmq': } ->

  # create rabbitmq sensu user
  rabbitmq_user { "${sensu_rabbitmq_user}":
    admin    => true,
    password => $sensu_rabbitmq_pass,
  } ->

  rabbitmq_vhost { '/sensu':
    ensure => present,
  } ->

  rabbitmq_user_permissions { "${sensu_rabbitmq_user}@/":
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*',
  } ->

  rabbitmq_user_permissions { "${sensu_rabbitmq_user}@/sensu":
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*',
  }

  # install npm, ruby/gem, json gem and sensu postgres plugin gem globally
  $apt_packages = [
    'npm',
    'ruby',
    'libpq-dev',
    'ruby-all-dev',
    'ntp',
  ]
  $gem_packages = [
    'json',
    'sensu-plugins-postgres',
  ]

  ensure_packages($apt_packages, {
    ensure => installed,
    before => Package[$gem_packages],
  })

  ensure_packages($gem_packages, {
    ensure   => installed,
    provider => gem,
  })

  # install postgresql, create user and db
  class { 'postgresql::server':
    listen_addresses        => '*',
    ip_mask_allow_all_users => '0.0.0.0/0',
    ipv4acls                => ['host all all 0.0.0.0/0 md5'],
    postgres_password       => $postgresql_pass,
  }

  postgresql::server::config_entry { 'max_connections':
    value => 100,
  }

  postgresql::server::db { 'graphite':
    user     => $graphite_sql_user,
    password => postgresql_password($graphite_sql_user, $graphite_sql_pass),
  }

  postgresql::server::db { 'grafana':
    user     => $grafana_sql_user,
    password => postgresql_password($grafana_sql_user, $grafana_sql_pass),
  }

  # install memcached
  # TODO: find a way to replace with Redis or remove
  class { 'memcached':
    max_memory => $memcached_max_memory
  }

  # install redis
  class { '::redis':
    bind => '0.0.0.0',
  }

  # install nginx for the proxy passes
  class { 'nginx': }

  # install uwsgi for graphite
  class { 'uwsgi': }

  # create graphite user and group
  group { 'graphite':
    ensure => present
  } ->

  user { 'graphite':
    ensure => present,
    gid    => 'graphite'
  }
}