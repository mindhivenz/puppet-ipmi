# Changelog

All notable changes after forking will be documented in this file.

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
