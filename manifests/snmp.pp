# @summary Sets the BMC SNMP community string
define ipmi::snmp (
  String $snmp        = 'public',
  Integer[1] $channel = 1,
) {
  $current_snmp = "ipmitool lan print ${channel} | grep 'SNMP Community String' | sed -e 's/.* : //g'"

  exec { "ipmi_set_snmp_${channel}":
    command => "/usr/bin/ipmitool lan set ${channel} snmp ${snmp}",
    onlyif  => "/usr/bin/test \"$(${current_snmp})\" != \"${snmp}\"",
  }
}
