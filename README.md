Puppet ipmi Module
==================

Overview
--------

Manages BMC using ipmitool with optional [Foreman](https://theforeman.org/) integration.

Description
-----------

Forked from [jhoblitt-ipmi](https://forge.puppet.com/jhoblitt/ipmi) with much thanks to the original author.

- Installs the [OpenIPMI](http://openipmi.sourceforge.net/) package and service
- Provides IPMI LAN, user, management controller (`ipmi_mc_info`) and FRU inventory (`ipmi_fru`) facts
- Adding/updating/disabling of IPMI users. Passwords are 1 to 20 characters. Disabled users also lose channel access and SOL
- Purging users beyond those wanted
- Setting of IPMI LAN network settings
- LAN facts automatically will add/update BMC NIC interface in [Foreman](https://www.theforeman.org)
- User credentials from Foreman BMC interface can be applied to an IPMI user

Supports Ubuntu 20.04, 22.04 and 24.04 on Puppet 7 and 8 (including OpenVox 8). Only IPMI channel 1, or the channel in the `ipmi_channel` fact, is managed.

Usage
-----

### Examples

```puppet 
include ipmi
```

Manage IPMI users:
```puppet
class { ipmi:
    purge_users => true,
    foreman_user => true,
    users => [
        {
            username => 'ADMIN',
            password => Sensitive('secret'),
        }, 
    ],    
}
```

Development
-----------

See [AGENTS.md](AGENTS.md) for checking changes, the VoxBox gotchas and building. It is shared by every module and synced from [mindhivenz/msync](https://github.com/mindhivenz/msync).
