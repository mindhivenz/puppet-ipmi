# Downtime

This file is shared by every control repo and `puppet-*` module and synced from [mindhivenz/msync](https://github.com/mindhivenz/msync). Change it there, not here.

Each site has a daily downtime, usually 2 hours in the early morning local time. It is a Datadog downtime scoped to the site, with `MAINTENANCE_WINDOW` in its message. While it runs, every host at the site is in downtime.

Any change that can disrupt a host in service is applied only in downtime: package and Helm upgrades, service restarts, reboots and risky config changes. Outside downtime, Puppet keeps the host at its installed state. Gate every such change by default.

## Gating a change

These functions come from [mindhivenz/puppet-datadog](https://github.com/mindhivenz/puppet-datadog).

* `datadog::downtime_upgrade($version = 'latest', $key = undef)` returns `$version` in downtime and `present` outside it. Use it as the `ensure` or `version` of a package, Helm release or similar. A missing resource is still installed straight away; only upgrades wait for downtime.
* `datadog::is_downtime($key = undef)` returns a Boolean. Use it for any other disruptive change, such as config that restarts a service, a migration, or removing an old release.
* `$key` names a component, such as `redis`, `nvidia` or `ptp`. When the site is in downtime, every key is too. A key lets an operator apply one component's gated changes on their own (see Forcing downtime). Give a component a key when it is risky enough to upgrade on its own.

Never use an ungated `ensure => latest`.

## Forcing downtime

* For one run: `FACTER_downtime=true puppet agent -t` applies every gated change. `FACTER_downtime=<key> puppet agent -t` applies only that key's changes.
* Set Hiera `datadog::downtime::mode: always` to keep a site in downtime permanently; test sites use this so failed upgrades show up immediately. `never` turns downtime off.

## Timing

A gated change reaches a host at its site's next downtime, up to a day after it lands in the host's Puppet environment. To apply it sooner, force downtime on that host.
