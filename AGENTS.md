# Puppet module

This file is shared by every `puppet-*` module and synced from [mindhivenz/msync](https://github.com/mindhivenz/msync). Change it there, not here.

The module is managed with [jig](https://github.com/voxpupuli/jig) (`jig.toml` beside `metadata.json`). Checks run inside the [VoxBox](https://github.com/voxpupuli/container-voxbox) container, so the host needs only jig and Docker. Host Ruby is not used. jig is also in the image: run it with `--entrypoint jig`.

**Creating a module, or changing its GitHub access:** follow the Confluence page [Puppet module dev](https://mindhive-global.atlassian.net/wiki/x/sgAdLQ) first, including its once-only Publishing steps. A missed step surfaces only on the Puppet server, where every control-repo environment using the module fails to compile.

## Checking changes

After any change, validate, lint, rubocop and spec must all pass. A failure is blocking. CI runs the same four on every push and pull request.

The pinned image ref is `VOXBOX_IMAGE` in `.github/workflows/ci.yml`, the single source of truth. Run with the same ref:

```sh
export JIG_RUNNER_TYPE=voxbox
export JIG_RUNNER_IMAGE=$(sed -n 's/^  VOXBOX_IMAGE: //p' .github/workflows/ci.yml)
jig validate     # syntax, puppet-lint and rubocop
```

Run the rspec-puppet unit tests with `scripts/voxbox.sh`, which runs the container with the pinned image. Its entrypoint is `rake`, so any rake task works, such as `lint_fix` or `rubocop:autocorrect`. Drop `SPEC` to run every spec:

```sh
SPEC=spec/classes/<name>_spec.rb scripts/voxbox.sh fixtures:prep spec:standalone
```

* Use `fixtures:prep spec:standalone` rather than `spec`, which deletes the fixtures after a passing run (see Fixtures). CI runs `spec`.
* The script lets the container clone private `mindhivenz` fixtures with your `gh` token, as CI does with its App token.

Spec both sides of every downtime gate. With puppet-datadog as a fixture, turn off the Datadog lookup in `pre_condition`, then set the fact `downtime: 'true'` (or the component's key) in the in-downtime context:

```puppet
class { 'datadog::downtime':
  mode                => never,
  unattended_upgrades => false,
}
```

## VoxBox gotchas

* VoxBox uses its own `/opt/voxbox/Gemfile` and `/opt/voxbox/Rakefile`, so modules have neither, and msync deletes any that `jig convert` writes.
  * Put lint config in `.puppet-lint.rc`, not in Rakefile tweaks.
  * A gem the image lacks can't be added from the repo.
* Lint is Vox Pupuli strict: extra plugins, and warnings fail the run. Run `lint_fix` first, then fix the rest by hand.
  * `lint_fix` can emit `else {[] }`, which fails a whitespace check however it is spaced. Rewrite it as a selector assigned to a variable outside the resource.
  * Move selectors and conditionals out of resource bodies into variables.
* facterdb has no legacy facts (`$::osfamily`, `ipaddress`, ...). Use structured facts such as `$facts['os']['family']`. If a fixture module you don't own reads a legacy fact, derive it in `spec/spec_helper_local.rb` with a comment saying why:
  `add_custom_fact :osfamily, ->(_os, facts) { facts[:os]['family'] }`
* In GitHub Actions, run the image with `docker run` from a host step. A `container:` job can't work, because the image is Alpine and JavaScript actions such as checkout fail in it.

## Spec customization

`spec/spec_helper.rb` is synced from msync, and `jig convert` overwrites it. Put spec customization in `spec/spec_helper_local.rb` and module facts in `spec/default_module_facts.yml`.

## Fixtures

Use https URLs for git fixtures in `.fixtures.yml`. CI has no SSH key. It clones private `mindhivenz` repos with a `cicd-mindhivenz` GitHub App token, so give the App access to a private repo before using it as a fixture. The App credentials are shared only with private repos, so a public module can't have private fixtures.

`fixtures:prep` installs the fixtures into `spec/fixtures/modules/`, which is gitignored, so an IDE can navigate into them. Never edit a fixture there. The git hooks keep it current, but after editing `.fixtures.yml` by hand, reinstall them with `scripts/voxbox.sh fixtures:prep`.

## Git hooks

The hooks in `.githooks/` reinstall `spec/fixtures/modules/` when a branch switch, pull or rebase changes `.fixtures.yml`. If Docker isn't running, they warn and leave the fixtures stale. Each clone needs a one-off setup before git runs them. If `git config core.hooksPath` doesn't print `.githooks`, run:

```sh
git config core.hooksPath .githooks
```

## Downtime

Each site has a daily downtime, usually 2 hours in the early morning local time. Changes that could disrupt a host in service, such as upgrades, restarts and reboots, are applied only during it. Before adding or changing anything that could disrupt a host, read [docs/agents/downtime.md](docs/agents/downtime.md).

## Adding components

`jig new class|defined_type|function|fact|task <name>` adds a component and its spec in the module layout.

## Building

* `jig build` writes the package to `pkg/`. It needs `summary` and `source` in `metadata.json`.
* The `[build]` section of `jig.toml` controls what is packaged. It ignores `.gitignore`.
  * `deny` mode packages only the allowlisted directories (`manifests/`, `files/`, ...) plus exceptions. It can't exclude a path inside an allowlisted directory, such as a local `files/**/.venv`.
  * In that case use `allow` mode, with exceptions listing the dev files.
* Check the package with `tar -tzf pkg/<file>.tar.gz`.
