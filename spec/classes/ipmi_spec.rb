# frozen_string_literal: true

require 'spec_helper'

describe 'ipmi' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ipmi::params') }
        it { is_expected.to contain_package('openipmi').with_ensure('installed') }
        it { is_expected.to contain_package('ipmitool').with_ensure('installed') }

        it do
          is_expected.to contain_augeas('/etc/default/openipmi')
            .with(context: '/files/etc/default/openipmi', changes: 'set IPMI_WATCHDOG no')
            .that_subscribes_to(['Package[openipmi]', 'Package[ipmitool]'])
            .that_notifies('Service[openipmi]')
        end

        it do
          is_expected.to contain_service('openipmi')
            .with(ensure: 'running', enable: true, hasrestart: true)
            .that_notifies('Service[ipmievd]')
        end

        it { is_expected.to contain_service('ipmievd').with(ensure: 'stopped', enable: false, hasrestart: true) }
        it { is_expected.to have_ipmi__user_resource_count(0) }
        it { is_expected.to have_ipmi__network_resource_count(0) }
        it { is_expected.to have_ipmi__snmp_resource_count(0) }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('openipmi').with_ensure('absent') }
        it { is_expected.to contain_package('ipmitool').with_ensure('absent') }
        it { is_expected.not_to contain_augeas('/etc/default/openipmi') }
        it { is_expected.not_to contain_service('openipmi') }
        it { is_expected.not_to contain_service('ipmievd') }
      end

      context 'with watchdog => true' do
        let(:params) { { watchdog: true } }

        it { is_expected.to contain_augeas('/etc/default/openipmi').with_changes('set IPMI_WATCHDOG yes') }
      end

      context 'with ipmievd_service_ensure => running' do
        let(:params) { { ipmievd_service_ensure: 'running' } }

        it { is_expected.to contain_service('ipmievd').with(ensure: 'running', enable: true) }
      end

      context 'with an ipmi_channel fact' do
        let(:facts) { os_facts.merge(ipmi_channel: 2) }
        let(:params) do
          {
            users: [{ id: 3, username: 'admin' }],
            network: { type: 'dhcp' },
            snmp: 'community',
          }
        end

        it { is_expected.to contain_ipmi__user('id_3').with_channel(2) }
        it { is_expected.to contain_ipmi__network('init').with_channel(2) }
        it { is_expected.to contain_ipmi__snmp('init').with(snmp: 'community', channel: 2) }
      end

      context 'with network' do
        let(:params) do
          { network: { type: 'static', ip: '10.0.0.5', netmask: '255.255.0.0', gateway: '10.0.0.1' } }
        end

        it do
          is_expected.to contain_ipmi__network('init')
            .with(type: 'static', ip: '10.0.0.5', netmask: '255.255.0.0', gateway: '10.0.0.1', channel: 1)
            .that_requires('Service[openipmi]')
        end
      end

      context 'with network naming its own channel' do
        let(:params) { { network: { type: 'dhcp', channel: 5 } } }

        it { is_expected.to compile.and_raise_error(%r{network.*unrecognized key 'channel'}) }
      end

      context 'with a user naming its own channel' do
        let(:params) { { users: [{ id: 3, username: 'admin', channel: 5 }] } }

        it { is_expected.to compile.and_raise_error(%r{users.*unrecognized key 'channel'}) }
      end

      context 'with snmp' do
        let(:params) { { snmp: 'community' } }

        it { is_expected.to contain_ipmi__snmp('init').with(snmp: 'community', channel: 1).that_requires('Service[openipmi]') }
      end

      context 'with ipmi facts from a BMC' do
        let(:existing_users) do
          [
            { 'id' => 1, 'username' => '', 'fixed_name' => true, 'enabled' => false },
            { 'id' => 2, 'username' => 'ADMIN', 'fixed_name' => true, 'enabled' => true, 'privilege' => 4 },
          ]
        end
        let(:facts) do
          os_facts.merge(ipmi_macaddress: 'ac:1f:6b:7f:d4:ce', ipmi_max_users: 10, ipmi_users: existing_users)
        end

        context 'with users given ids' do
          let(:params) do
            {
              users: [
                { id: 2, username: 'ADMIN', password: 'secret' },
                { id: 3, username: 'other', privilege: 1, ensure: 'disabled' },
              ],
            }
          end

          it { is_expected.to contain_ipmi__user('id_2').with(id: 2, username: 'ADMIN', password: 'secret', channel: 1).that_requires('Service[openipmi]') }
          it { is_expected.to contain_ipmi__user('id_3').with(id: 3, username: 'other', privilege: 1, ensure: 'disabled', channel: 1) }
          it { is_expected.to have_ipmi__user_resource_count(2) }
        end

        context 'with a user matching an existing username' do
          let(:params) { { users: [{ username: 'ADMIN', password: 'secret' }] } }

          it { is_expected.to contain_ipmi__user('id_2').with(id: 2, username: 'ADMIN', password: 'secret') }
        end

        context 'with users matching no existing username' do
          let(:params) do
            { users: [{ username: 'other1', password: 'secret1' }, { username: 'other2', password: 'secret2' }] }
          end

          it { is_expected.to contain_ipmi__user('id_3').with(id: 3, username: 'other1', password: 'secret1') }
          it { is_expected.to contain_ipmi__user('id_4').with(id: 4, username: 'other2', password: 'secret2') }
        end

        context 'with a gap in the existing ids' do
          let(:existing_users) do
            [
              { 'id' => 2, 'username' => 'ADMIN', 'fixed_name' => true, 'enabled' => true },
              { 'id' => 4, 'username' => 'other', 'fixed_name' => false, 'enabled' => true },
            ]
          end
          let(:params) { { users: [{ username: 'newuser' }, { username: 'another' }] } }

          it { is_expected.to contain_ipmi__user('id_1').with_username('newuser') }
          it { is_expected.to contain_ipmi__user('id_3').with_username('another') }
        end

        context 'with a new user that is not given the id another user claims' do
          let(:params) { { users: [{ username: 'newuser' }, { id: 3, username: 'fixed' }] } }

          it { is_expected.to contain_ipmi__user('id_3').with_username('fixed') }
          it { is_expected.to contain_ipmi__user('id_4').with_username('newuser') }
        end

        context 'with a new user to be absent' do
          let(:params) { { users: [{ username: 'other', ensure: 'absent' }] } }

          it { is_expected.to compile.and_raise_error(%r{Can't have user ensure => absent when no id specified}) }
        end

        context 'with every id taken' do
          let(:facts) { super().merge(ipmi_max_users: 2) }
          let(:params) { { users: [{ username: 'other' }] } }

          it { is_expected.to compile.and_raise_error(%r{Max users is 2 and all ids are taken}) }
        end

        context 'with purge_users => true' do
          let(:existing_users) do
            [
              { 'id' => 1, 'username' => '', 'fixed_name' => true, 'enabled' => false },
              { 'id' => 2, 'username' => 'ADMIN', 'fixed_name' => true, 'enabled' => true },
              { 'id' => 3, 'username' => 'stale', 'fixed_name' => false, 'enabled' => true },
            ]
          end
          let(:params) { { purge_users: true, users: [{ username: 'ADMIN' }] } }

          it { is_expected.to contain_ipmi__user('id_2').with(username: 'ADMIN', ensure: 'present') }
          it { is_expected.to contain_ipmi__user('id_3').with(id: 3, ensure: 'absent', channel: 1) }
          it { is_expected.not_to contain_ipmi__user('id_1') }
        end

        context 'with purge_users => true and no users' do
          let(:params) { { purge_users: true } }

          it { is_expected.to contain_ipmi__user('id_2').with(id: 2, ensure: 'absent') }
          it { is_expected.to have_ipmi__user_resource_count(1) }
        end
      end

      context 'without ipmi facts, as on the first run' do
        context 'with users' do
          let(:params) { { users: [{ username: 'ADMIN', password: 'secret' }, { id: 3, username: 'other' }] } }

          it { is_expected.to contain_ipmi__user('id_3').with_username('other') }
          it { is_expected.to have_ipmi__user_resource_count(1) }
        end

        context 'with purge_users => true' do
          let(:params) { { purge_users: true, users: [{ id: 3, username: 'other' }] } }

          it { is_expected.to have_ipmi__user_resource_count(1) }
        end
      end

      context 'with foreman_user' do
        let(:bmc_interface) { { 'mac' => 'ac:1f:6b:7f:d4:ce', 'type' => 'BMC', 'username' => 'ADMIN', 'password' => 'SECRET' } }
        let(:node_params) { { 'foreman_interfaces' => [{ 'mac' => 'ac:1f:6b:7f:d5:16', 'type' => 'Interface' }, bmc_interface] } }
        let(:existing_users) do
          [
            { 'id' => 1, 'username' => '', 'fixed_name' => true, 'enabled' => false },
            { 'id' => 2, 'username' => 'ADMIN', 'fixed_name' => true, 'enabled' => true },
          ]
        end
        let(:facts) do
          os_facts.merge(ipmi_macaddress: 'ac:1f:6b:7f:d4:ce', ipmi_max_users: 10, ipmi_users: existing_users)
        end

        context '=> false' do
          it { is_expected.to have_ipmi__user_resource_count(0) }
        end

        [true, 'optional'].each do |foreman_user|
          context "=> #{foreman_user.inspect}" do
            let(:params) { { foreman_user: foreman_user } }

            context 'with a BMC interface matching an existing user' do
              it { is_expected.to contain_ipmi__user('id_2').with(id: 2, username: 'ADMIN', password: sensitive('SECRET'), privilege: 4, channel: 1) }
              it { is_expected.to have_ipmi__user_resource_count(1) }
            end

            context 'with foreman_user_privilege' do
              let(:params) { super().merge(foreman_user_privilege: 3) }

              it { is_expected.to contain_ipmi__user('id_2').with_privilege(3) }
            end

            context 'with a BMC interface for a new user' do
              let(:existing_users) { [{ 'id' => 2, 'username' => 'root', 'fixed_name' => true, 'enabled' => true }] }

              it { is_expected.to contain_ipmi__user('id_1').with(username: 'ADMIN', password: sensitive('SECRET'), privilege: 4) }
              it { is_expected.to have_ipmi__user_resource_count(1) }
            end

            context 'with purge_users => true' do
              let(:existing_users) do
                [
                  { 'id' => 1, 'username' => '', 'fixed_name' => true, 'enabled' => false },
                  { 'id' => 2, 'username' => 'ADMIN', 'fixed_name' => true, 'enabled' => true },
                  { 'id' => 3, 'username' => 'stale', 'fixed_name' => false, 'enabled' => true },
                ]
              end
              let(:params) { super().merge(purge_users: true) }

              it { is_expected.to contain_ipmi__user('id_2').with(username: 'ADMIN', password: sensitive('SECRET'), ensure: 'present') }
              it { is_expected.to contain_ipmi__user('id_3').with_ensure('absent') }
              it { is_expected.to have_ipmi__user_resource_count(2) }
            end

            context 'without foreman_interfaces from the Foreman ENC' do
              let(:node_params) { {} }

              it { is_expected.to compile.and_raise_error(%r{foreman_user set but 'foreman_interfaces' not passed from Foreman ENC}) }
            end

            context 'without an ipmi_macaddress fact, as on the first run' do
              let(:facts) { os_facts }

              it { is_expected.to have_ipmi__user_resource_count(0) }
            end
          end
        end

        {
          'no BMC interface matching the ipmi_macaddress fact' => [
            { 'mac' => 'ff:ff:ff:ff:ff:ff' }, %r{No BMC interface matching ac:1f:6b:7f:d4:ce},
          ],
          'a non-BMC interface matching the ipmi_macaddress fact' => [
            { 'type' => 'Interface' }, %r{No BMC interface matching ac:1f:6b:7f:d4:ce},
          ],
          'a BMC interface without a username' => [{ 'username' => '' }, %r{No username on BMC interface}],
          'a BMC interface without a password' => [{ 'password' => '' }, %r{No password on BMC interface}],
        }.each do |description, (override, error)|
          context "with #{description}" do
            let(:bmc_interface) { super().merge(override) }

            context 'when required' do
              let(:params) { { foreman_user: true } }

              it { is_expected.to compile.and_raise_error(error) }
            end

            context 'when optional' do
              let(:params) { { foreman_user: 'optional' } }

              it { is_expected.to compile.with_all_deps }
              it { is_expected.to have_ipmi__user_resource_count(0) }
            end
          end
        end
      end

      context 'on an unsupported OS family' do
        let(:facts) { os_facts.merge(os: os_facts[:os].merge('family' => 'RedHat', 'name' => 'Rocky')) }

        it { is_expected.to compile.and_raise_error(%r{not supported on Rocky}) }
      end
    end
  end
end
