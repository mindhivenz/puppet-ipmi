# @summary Adds, updates or disables a BMC user
define ipmi::user (
  Integer[1] $id,
  Enum[present, enabled, absent, disabled] $ensure                     = present,
  String $username                                                     = $title,
  Optional[Variant[Sensitive[String[1, 20]], String[1, 20]]] $password = undef,
  Integer[1, 4] $privilege                                             = 4,
  Integer[1] $channel                                                  = 1,
) {
  $priv_text = case $privilege {
    1: { 'CALLBACK' }
    2: { 'USER' }
    3: { 'OPERATOR' }
    4: { 'ADMINISTRATOR' }
    default: { fail('invalid privilege level specified') }
  }

  $tool = '/usr/bin/ipmitool'

  if $ensure in [present, enabled] {
    exec { "ipmi_user_add_${title}":
      command => "${tool} user set name ${id} ${username}",
      unless  => "${tool} channel getaccess ${channel} ${id} | grep '^User Name.*: ${username}$'",
    }

    $refresh_execs = [
      Exec["ipmi_user_enable_sol_${title}"],
    ]

    exec { "ipmi_user_priv_${title}":
      command => "${tool} channel setaccess ${channel} ${id} callin=on ipmi=on link=on privilege=${privilege}",
      unless  => "${tool} channel getaccess ${channel} ${id} | grep '^Privilege Level.*: ${priv_text}$'",
      require => Exec["ipmi_user_add_${title}"],
      notify  => $refresh_execs,
    }

    if $password {
      $plain_password = $password.unwrap
      $escaped_password = stdlib::shell_escape($plain_password)
      # ipmitool defaults to 16 byte capacity, which can't hold a longer password
      $capacity = if $plain_password.length > 16 { 20 } else { 16 }
      exec { "ipmi_user_setpw_${title}":
        command => Sensitive("${tool} user set password ${id} ${escaped_password} ${capacity}"),
        unless  => Sensitive("${tool} user test ${id} ${capacity} ${escaped_password}"),
        require => Exec["ipmi_user_add_${title}"],
        notify  => $refresh_execs,
      }
    }

    exec { "ipmi_user_enable_${title}":
      command => "${tool} user enable ${id}",
      unless  => "${tool} channel getaccess ${channel} ${id} | grep '^Enable Status.*: enabled$'",
      require => Exec["ipmi_user_add_${title}"],
      notify  => $refresh_execs,
    }

    exec { "ipmi_user_enable_sol_${title}":
      command     => "${tool} sol payload enable ${channel} ${id}",
      refreshonly => true,
    }
  } else {
    $refresh_execs = [
      Exec["ipmi_user_disable_sol_${title}"],
    ]

    # Some BMC firmware still grants access to a disabled user, so its channel access is revoked too
    exec { "ipmi_user_revoke_${title}":
      command => "${tool} channel setaccess ${channel} ${id} callin=off ipmi=off link=off privilege=15",
      unless  => "${tool} channel getaccess ${channel} ${id} | grep '^Privilege Level.*: NO ACCESS$'",
      notify  => $refresh_execs,
    }

    exec { "ipmi_user_disable_${title}":
      command => "${tool} user disable ${id}",
      unless  => "${tool} channel getaccess ${channel} ${id} | grep '^Enable Status.*: disabled$'",
      notify  => $refresh_execs,
    }

    exec { "ipmi_user_disable_sol_${title}":
      command     => "${tool} sol payload disable ${channel} ${id}",
      refreshonly => true,
    }
  }
}
