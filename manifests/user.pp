# @summary Adds, updates or disables a BMC user
define ipmi::user (
  Integer[1] $id,
  Enum[present, enabled, absent, disabled] $ensure       = present,
  String $username                                       = $title,
  Optional[Variant[Sensitive[String], String]] $password = undef,
  Integer[1, 4] $privilege                               = 4,
  Integer[1] $channel                                    = 1,
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
      $escaped_password = stdlib::shell_escape($password.unwrap)
      exec { "ipmi_user_setpw_${title}":
        command => Sensitive("${tool} user set password ${id} ${escaped_password}"),
        unless  => Sensitive("${tool} user test ${id} 16 ${escaped_password}"),
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
    exec { "ipmi_user_disable_${title}":
      command => "${tool} user disable ${id}",
      unless  => "${tool} channel getaccess ${channel} ${id} | grep '^Enable Status.*: disabled$'",
    }
  }
}
