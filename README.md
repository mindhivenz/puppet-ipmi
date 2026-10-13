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

The module is managed with [jig](https://github.com/voxpupuli/jig). Validation and unit tests run inside the [VoxBox](https://github.com/voxpupuli/container-voxbox) container, so the only host requirements are jig and Docker (or Podman).

### Setup

Install jig from its [releases](https://github.com/voxpupuli/jig/releases), then point its runner at the same VoxBox image CI uses (see `VOXBOX_IMAGE` in `.github/workflows/ci.yml`):

```shell
export JIG_RUNNER_TYPE=voxbox
export JIG_RUNNER_IMAGE=ghcr.io/voxpupuli/voxbox:10.1.0-openvox8.30.0@sha256:01bb8ce5e24d5b111934660f75e2786b4d7c7adcaa7518a564856d1d3041d10d
```

To make this permanent, put the equivalent `[runner]` section in your jig config file instead (see the [jig voxbox docs](https://github.com/voxpupuli/jig/blob/main/docs/voxbox.md)).

### Validate and test

```shell
jig validate     # syntax, puppet-lint and rubocop
jig test unit    # rspec-puppet and custom fact unit tests
```

Run a single spec file by calling the container directly:

```shell
docker run --rm -v "$PWD:/repo" -e SPEC=spec/classes/ipmi_spec.rb "$JIG_RUNNER_IMAGE" spec
```

### Build

```shell
jig build
```

The package is written to `pkg/`. Which files are packaged is controlled by the `[build]` section of `jig.toml`.
