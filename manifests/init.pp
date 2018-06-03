# == Class: monitoring
#
# Full description of class monitoring here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'monitoring':
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2018 Your name here, unless otherwise noted.
#
class monitoring (
  String            $env                      = $::monitoring::params::env,
  String            $domain                   = $::monitoring::params::domain,
  Optional[String]  $postgresql_pass          = $::monitoring::params::postgresql_pass,
  Optional[String]  $sensu_rabbitmq_user      = $::monitoring::params::sensu_rabbitmq_user,
  Optional[String]  $sensu_rabbitmq_pass      = $::monitoring::params::sensu_rabbitmq_pass,
  Optional[String]  $graphite_sql_user        = $::monitoring::params::graphite_sql_user,
  Optional[String]  $graphite_sql_pass        = $::monitoring::params::graphite_sql_pass,
  Optional[String]  $grafana_sql_user         = $::monitoring::params::grafana_sql_user,
  Optional[String]  $grafana_sql_pass         = $::monitoring::params::grafana_sql_pass,
  Optional[String]  $grafana_admin_user       = $::monitoring::params::grafana_admin_user,
  Optional[String]  $grafana_admin_pass       = $::monitoring::params::grafana_admin_pass,
  Optional[String]  $memcached_max_memory     = $::monitoring::params::memcached_max_memory,
  Optional[String]  $graphite_secret_key      = $::monitoring::params::graphite_secret_key,
  Optional[String]  $sensu_api_user           = $::monitoring::params::sensu_api_user,
  Optional[String]  $sensu_api_pass           = $::monitoring::params::sensu_api_pass,
  String            $email_user               = $::monitoring::params::email_user,
  String            $email_password           = $::monitoring::params::email_password,
  String            $email_server             = $::monitoring::params::email_server,
  String            $email_from               = $::monitoring::params::email_from,
  String            $email_to                 = $::monitoring::params::email_to,
  Integer           $email_port               = $::monitoring::params::email_port,
  Array[String]     $additional_subscriptions = $::monitoring::params::additional_subscriptions,
) inherits monitoring::params {

  if($env == undef) {
    fail('An environment is needed to set up monitoring')
  }

  if($domain == undef) {
    fail('A domain is needed to set up monitoring')
  }

  contain ::monitoring::preinstall
  contain ::monitoring::install

  Class['monitoring::preinstall']
    -> Class['monitoring::install']
}
