# Changelog

All notable changes after forking will be documented in this file.

## Release 4.7.0

**Features**
- Works on OpenVox 8: structured facts replace `osfamily` and `operatingsystemmajrelease`
- Supports Puppet 7 and 8, on Ubuntu 20.04, 22.04 and 24.04
- User passwords accept `Sensitive` and stay out of logs and reports; the Foreman BMC password is always `Sensitive`

**Changed**
- Requires `stdlib` 9

**Fix**
- `snmp` sets the community string (its check command was broken over two lines)
- User passwords are shell-escaped, so quotes and `$` no longer break `ipmitool`
- `foreman_user` fails with a clear message when Foreman sends no `foreman_interfaces`

**Removed**
- RedHat family support
- The `channel` key in `users` and `network` entries. The `ipmi_channel` fact always overrode it, and in `network` it failed to compile

## Release 4.6.1

**Fix**
- Ubuntu version 

## Release 4.6.0

**Features**
- Allow stdlib v9 

## Release 4.5.0

**Features**
- Full typing for `users` and `network` on `ipmi` 

## Release 4.4.0

**Features**
- Allow `stdlib` up to version < 9.0.0

## Release 4.3.0

**Features**
- Allow Puppet 7

## Release 4.1.0

**Features**
- Use `ensure_packages` to avoid package conflicts

## Release 4.0.0

**Features**
- Simplify sub-resources passed to `ipmi` class
- `users` passed to `ipmi` can have their id allocated:
    - to an existing id if username's match
    - otherwise, a new, unused id  

## Release 3.0.0

**Features**
- Apply user specified in Foreman BMC interface
- Purge (disable) unspecified `users`
- `ensure => disabled` to disable users
- `ensure => absent` to remove packages

**Internal**
- Converted to PDK
- Allow `stdlib` up to version < 7.0.0

**Limitations**
- Simplifying by restricting to channel 1 only
