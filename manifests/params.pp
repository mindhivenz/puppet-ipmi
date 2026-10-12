# @summary OS specific defaults for the ipmi class
#
# @api private
class ipmi::params {
  if $facts['os']['family'] != 'Debian' {
    fail("Module ${module_name} is not supported on ${facts['os']['name']}")
  }

  $channel = $facts.get('ipmi_channel', 1)
  $ipmi_package = ['openipmi', 'ipmitool']
  $config_location = '/etc/default/openipmi'
  $ipmi_service_name = 'openipmi'
}
