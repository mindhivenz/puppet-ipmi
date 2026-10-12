# @summary Sets the BMC LAN address source, and for static the address, netmask and gateway
define ipmi::network (
  Stdlib::IP::Address::V4::Nosubnet $ip      = '0.0.0.0',
  Stdlib::IP::Address::V4::Nosubnet $netmask = '255.255.255.0',
  Stdlib::IP::Address::V4::Nosubnet $gateway = '0.0.0.0',
  Enum[dhcp, static] $type                   = dhcp,
  Integer[1] $channel                        = 1,
) {
  $lan_print = "ipmitool lan print ${channel}"
  $dhcp_count = "$(${lan_print} | grep 'IP Address Source' | cut -f 2 -d : | grep -c DHCP)"

  if $type == dhcp {
    exec { "ipmi_set_dhcp_${channel}":
      command => "/usr/bin/ipmitool lan set ${channel} ipsrc dhcp",
      onlyif  => "/usr/bin/test ${dhcp_count} -eq 0",
    }
  } else {
    exec { "ipmi_set_static_${channel}":
      command => "/usr/bin/ipmitool lan set ${channel} ipsrc static",
      onlyif  => "/usr/bin/test ${dhcp_count} -eq 1",
      notify  => [
        Exec["ipmi_set_ipaddr_${channel}"],
        Exec["ipmi_set_defgw_${channel}"],
        Exec["ipmi_set_netmask_${channel}"],
      ],
    }

    exec { "ipmi_set_ipaddr_${channel}":
      command => "/usr/bin/ipmitool lan set ${channel} ipaddr ${ip}",
      onlyif  => "/usr/bin/test \"$(${lan_print} | grep 'IP Address  ' | sed -e 's/.* : //g')\" != \"${ip}\"",
    }

    exec { "ipmi_set_defgw_${channel}":
      command => "/usr/bin/ipmitool lan set ${channel} defgw ipaddr ${gateway}",
      onlyif  => "/usr/bin/test \"$(${lan_print} | grep 'Default Gateway IP' | sed -e 's/.* : //g')\" != \"${gateway}\"",
    }

    exec { "ipmi_set_netmask_${channel}":
      command => "/usr/bin/ipmitool lan set ${channel} netmask ${netmask}",
      onlyif  => "/usr/bin/test \"$(${lan_print} | grep 'Subnet Mask' | sed -e 's/.* : //g')\" != \"${netmask}\"",
    }
  }
}
