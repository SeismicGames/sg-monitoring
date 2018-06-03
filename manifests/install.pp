class monitoring::install {
  $env                      = $::monitoring::env
  $domain                   = $::monitoring::domain
  $graphite_secret_key      = $::monitoring::graphite_secret_key
  $graphite_sql_user        = $::monitoring::graphite_sql_user
  $graphite_sql_pass        = $::monitoring::graphite_sql_pass
  $grafana_sql_user         = $::monitoring::grafana_sql_user
  $grafana_sql_pass         = $::monitoring::grafana_sql_pass
  $grafana_admin_user       = $::monitoring::grafana_admin_user
  $grafana_admin_pass       = $::monitoring::grafana_admin_pass
  $sensu_rabbitmq_user      = $::monitoring::sensu_rabbitmq_user
  $sensu_rabbitmq_pass      = $::monitoring::sensu_rabbitmq_pass
  $sensu_api_user           = $::monitoring::sensu_api_user
  $sensu_api_pass           = $::monitoring::sensu_api_pass
  $email_user               = $::monitoring::email_user
  $email_password           = $::monitoring::email_password
  $email_server             = $::monitoring::email_server
  $email_from               = $::monitoring::email_from
  $email_to                 = $::monitoring::email_to
  $email_port               = $::monitoring::email_port
  $additional_subscriptions = $::monitoring::additional_subscriptions
  if($graphite_secret_key == undef) {
    $secret = fqdn_rand_string(10)
  } else {
    $secret = $graphite_secret_key
  }

  if($env == 'local') {
    $final_domain = $::ipaddress_enp0s8
  } else {
    $final_domain = $domain
  }

  $sensu_packages = [
    'sensu-plugins-http',
    'sensu-plugins-rabbitmq',
    'sensu-plugins-mailer',
    'sensu-plugins-uchiwa',
    'sensu-plugins-graphite',
    'sensu-plugins-ntp',
    'sensu-plugins-memory-checks',
    'sensu-plugins-cpu-checks',
    'sensu-plugins-disk-checks',
  ]

  # install graphite
  class { 'graphite':
    gr_max_updates_per_second => 100,
    gr_timezone               => 'America/Los_Angeles',
    secret_key                => $secret,
    gr_web_server             => 'none',
    gr_disable_webapp_cache   => true,
    gr_web_user               => 'graphite',
    gr_web_group              => 'graphite',

    gr_django_db_engine       => 'django.db.backends.postgresql_psycopg2',
    gr_django_db_name         => 'graphite',
    gr_django_db_user         => $graphite_sql_user,
    gr_django_db_password     => $graphite_sql_pass,
    gr_django_db_host         => '127.0.0.1',
    gr_django_db_port         => 5432,
    gr_memcache_hosts         => ['127.0.0.1:11211'],

    require                   => Class['monitoring::preinstall'],
  }

  uwsgi::resource::config { 'graphite.ini':
    plugins_dir  => '/usr/lib/uwsgi',
    plugins      => 'python',
    uid          => 'graphite',
    gid          => 'graphite',
    socket       => '/opt/graphite/graphite.sock',
    wsgi_file    => '/opt/graphite/webapp/graphite/graphite_wsgi.py',
    chmod_socket => 666,
    require      => [
      Class['graphite'],
    ],
    notify       => Service['nginx'],
  }

  # install grafana
  class { 'grafana':
    cfg               => {
      app_mode        => 'production',
      server          => {
        http_port     => 8000,
        domain        => $final_domain,
        root_url      => '%(protocol)s://%(domain)s/grafana/',
      },
      database        => {
        type          => 'postgres',
        host          => '127.0.0.1:5432',
        name          => 'grafana',
        user          => $grafana_sql_user,
        password      => $grafana_sql_pass,
      },
      users           => {
        allow_sign_up => false,
      },
    },

    require => Class['monitoring::preinstall'],
  }

  http_conn_validator { 'grafana-http-validator':
    host     => 'localhost',
    port     => 8000,
    use_ssl  => false,
    test_url => '/public/img/grafana_icon.svg',
    require  => Class['grafana'],
  } ->

  grafana_datasource { 'graphite':
    grafana_url       => "http://localhost:8000",
    grafana_user      => $grafana_admin_user,
    grafana_password  => $grafana_admin_pass,
    type              => 'graphite',
    url               => 'http://localhost:8080',
    database          => 'graphite',
    access_mode       => 'proxy',
    basic_auth        => false,
    is_default        => true,

    require           => [
      Class['grafana'],
      Class['graphite']
    ],
  }

  # install statsd
  class { 'statsd':
    backends     => ['./backends/graphite'],
    graphiteHost => 'localhost',

    require      => Class['monitoring::preinstall'],
  }

  # install sensu
  class { 'sensu':
    rabbitmq_host                     => 'localhost',
    rabbitmq_user                     => $sensu_rabbitmq_user,
    rabbitmq_password                 => $sensu_rabbitmq_pass,
    server                            => true,
    api                               => true,
    api_user                          => $sensu_api_user,
    api_password                      => $sensu_api_pass,
    handlers                          => {
      'mailer'                        => {
        command                       => '/opt/sensu/embedded/bin/handler-mailer.rb',
        type                          => 'pipe',
        config                        => {
          'admin_gui'                 => 'http://localhost:3000',
          'mail_from'                 => $email_from,
          'mail_to'                   => $email_to,
          'smtp_address'              => $email_server,
          'smtp_username'             => $email_user,
          'smtp_password'             => $email_password,
          'smtp_use_tls'              => false,
          'delivery_method'           => 'smtp',
          'smtp_enable_starttls_auto' => true,
          'smtp_port'                 => $email_port,
        }
      }
    },
    subscriptions                     => ['all',],
    client_address                    => '127.0.0.1',
    client_name                       => "monitoring_${env}",

    require                           => Class['monitoring::preinstall'],
  }

  package { $sensu_packages:
    ensure   => installed,
    provider => sensu_gem,
  }

  # install uchiwa
  class { 'uchiwa':
    install_repo => false,
    user         => $sensu_api_user,
    pass         => $sensu_api_pass,

    require      => Class['sensu'],
  }

  # configure nginx
  nginx::resource::location { '= /':
    ensure              => present,
    server              => $final_domain,
    index_files         => [],
    location_cfg_append => {
      return            => '301 http://$host/grafana/',
    }
  }

  nginx::resource::location { '/graphite':
    ensure => present,
    server => $final_domain,
    uwsgi  => 'unix:///opt/graphite/graphite.sock',
  }

  nginx::resource::location { '/browser/header':
    ensure => present,
    server => $final_domain,
    uwsgi  => 'unix:///opt/graphite/graphite.sock',
  }

  nginx::resource::location { '/browser/usergraph':
    ensure => present,
    server => $final_domain,
    uwsgi  => 'unix:///opt/graphite/graphite.sock',
  }

  nginx::resource::location { '/composer':
    ensure => present,
    server => $final_domain,
    uwsgi  => 'unix:///opt/graphite/graphite.sock',
  }

  nginx::resource::location { '/content':
    ensure => present,
    server => $final_domain,
    uwsgi  => 'unix:///opt/graphite/graphite.sock',
  }

  nginx::resource::location { '/metrics/find/':
    ensure => present,
    server => $final_domain,
    uwsgi  => 'unix:///opt/graphite/graphite.sock',
  }

  nginx::resource::location { '/metrics/find':
    ensure => present,
    server => $final_domain,
    uwsgi  => 'unix:///opt/graphite/graphite.sock',
  }

  nginx::resource::location { '/render':
    ensure => present,
    server => $final_domain,
    uwsgi  => 'unix:///opt/graphite/graphite.sock',
  }

  nginx::resource::location { '/grafana/':
    ensure => present,
    server => $final_domain,
    proxy  => 'http://localhost:8000/',
  }

  nginx::resource::location { '/uchiwa/':
    ensure => present,
    server => $final_domain,
    proxy  => 'http://localhost:3000/',
  }

  nginx::resource::location { '~* /rabbitmq/(.*)':
    ensure          => present,
    server          => $final_domain,
    rewrite_rules   => [
      '^/rabbitmq/(.*)$ /$1 break',
    ],
    proxy           => 'http://localhost:15672',
    proxy_buffering => 'off',
  }

  nginx::resource::location { '~* /rabbitmq/api/(.*?)/(.*)':
    ensure          => present,
    server          => $final_domain,
    proxy           => 'http://localhost:15672/api/$1/%2F/$2?$query_string',
    proxy_buffering => 'off',
  }

  nginx::resource::server { $final_domain:
    listen_port          => 80,
    use_default_location => false,
    require              => [
      Class['graphite'],
      Class['grafana'],
      Class['uchiwa'],
      Uwsgi::Resource::Config['graphite.ini'],
    ]
  }

  # set up sensu health checks
  sensu::check { 'health_check_uchiwa':
    command     => "/opt/sensu/embedded/bin/check-uchiwa-health.rb -u ${sensu_api_user} -p ${sensu_api_pass}",
    subscribers => concat($additional_subscriptions, ['all', 'uchiwa',]),
    handlers    => ['mailer',],
  }

  sensu::check { 'health_check_grafana':
    command     => "/opt/sensu/embedded/bin/check-http.rb -u http://${final_domain}/grafana/ --response-code 302 -r",
    subscribers => concat($additional_subscriptions, ['all', 'grafana',]),
    handlers    => ['mailer',],
  }

  sensu::check { 'health_check_graphite':
    command     => "/opt/sensu/embedded/bin/check-http.rb -u http://${final_domain}/graphite/",
    subscribers => concat($additional_subscriptions, ['all', 'graphite',]),
    handlers    => ['mailer',],
  }

  sensu::check { 'health_check_rabbmitmq':
    command     => "/opt/sensu/embedded/bin/check-http.rb -u http://${final_domain}/rabbitmq/",
    subscribers => concat($additional_subscriptions, ['all', 'rabbmitmq',]),
    handlers    => ['mailer',],
  }

  sensu::check { 'health_check_postgres_alive':
    command     => "/usr/local/bin/check-postgres-alive.rb -d grafana -u ${grafana_sql_user} -p ${grafana_sql_pass}",
    subscribers => concat($additional_subscriptions, ['all', 'postgres',]),
    handlers    => ['mailer',],
  }

  sensu::check { 'memory_check':
    command     => "/opt/sensu/embedded/bin/check-memory-percent.rb -w 70 -c 80",
    subscribers => concat($additional_subscriptions, ['all', 'memory',]),
    handlers    => ['mailer',],
  }

  sensu::check { 'cpu_check':
    command     => "/opt/sensu/embedded/bin/check-cpu.rb",
    subscribers => concat($additional_subscriptions, ['all', 'cpu',]),
    handlers    => ['mailer',],
  }

  sensu::check { 'ntp_check':
    command     => "/opt/sensu/embedded/bin/check-ntp.rb  -w 100 -c 200",
    subscribers => concat($additional_subscriptions, ['all', 'ntp',]),
    handlers    => ['mailer',],
  }

  sensu::check { 'disk_usage_check':
    command     => "/opt/sensu/embedded/bin/check-disk-usage.rb",
    subscribers => concat($additional_subscriptions, ['all', 'disk',]),
    handlers    => ['mailer',],
  }
}