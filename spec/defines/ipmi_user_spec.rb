# frozen_string_literal: true

require 'spec_helper'

describe 'ipmi::user' do
  let(:title) { 'admin' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) { { id: 3 } }

      %w[present enabled].each do |ensure_value|
        context "with ensure => #{ensure_value}" do
          let(:params) { super().merge(ensure: ensure_value) }

          it { is_expected.to compile.with_all_deps }

          it do
            is_expected.to contain_exec('ipmi_user_add_admin').with(
              command: '/usr/bin/ipmitool user set name 3 admin',
              unless: "/usr/bin/ipmitool channel getaccess 1 3 | grep '^User Name.*: admin$'",
            )
          end

          it do
            is_expected.to contain_exec('ipmi_user_priv_admin').with(
              command: '/usr/bin/ipmitool channel setaccess 1 3 callin=on ipmi=on link=on privilege=4',
              unless: "/usr/bin/ipmitool channel getaccess 1 3 | grep '^Privilege Level.*: ADMINISTRATOR$'",
            ).that_requires('Exec[ipmi_user_add_admin]').that_notifies('Exec[ipmi_user_enable_sol_admin]')
          end

          it do
            is_expected.to contain_exec('ipmi_user_enable_admin').with(
              command: '/usr/bin/ipmitool user enable 3',
              unless: "/usr/bin/ipmitool channel getaccess 1 3 | grep '^Enable Status.*: enabled$'",
            ).that_requires('Exec[ipmi_user_add_admin]').that_notifies('Exec[ipmi_user_enable_sol_admin]')
          end

          it do
            is_expected.to contain_exec('ipmi_user_enable_sol_admin').with(
              command: '/usr/bin/ipmitool sol payload enable 1 3',
              refreshonly: true,
            )
          end

          it { is_expected.not_to contain_exec('ipmi_user_setpw_admin') }
          it { is_expected.not_to contain_exec('ipmi_user_disable_admin') }
        end
      end

      context 'with password, username and channel' do
        let(:params) { super().merge(password: 's3cret', username: 'operator', channel: 2) }

        it { is_expected.to contain_exec('ipmi_user_add_admin').with_command('/usr/bin/ipmitool user set name 3 operator') }

        it do
          is_expected.to contain_exec('ipmi_user_setpw_admin').with(
            command: sensitive('/usr/bin/ipmitool user set password 3 s3cret 16'),
            unless: sensitive('/usr/bin/ipmitool user test 3 16 s3cret'),
          ).that_requires('Exec[ipmi_user_add_admin]').that_notifies('Exec[ipmi_user_enable_sol_admin]')
        end

        it { is_expected.to contain_exec('ipmi_user_enable_sol_admin').with_command('/usr/bin/ipmitool sol payload enable 2 3') }
      end

      context 'with a Sensitive password holding shell metacharacters' do
        let(:params) { super().merge(password: sensitive("it's a $secret")) }

        it do
          is_expected.to contain_exec('ipmi_user_setpw_admin').with(
            command: sensitive(%q(/usr/bin/ipmitool user set password 3 it\'s\ a\ \$secret 16)),
            unless: sensitive(%q(/usr/bin/ipmitool user test 3 16 it\'s\ a\ \$secret)),
          )
        end
      end

      context 'with a password longer than 16 characters' do
        let(:params) { super().merge(password: sensitive('a' * 20)) }

        it do
          is_expected.to contain_exec('ipmi_user_setpw_admin').with(
            command: sensitive("/usr/bin/ipmitool user set password 3 #{'a' * 20} 20"),
            unless: sensitive("/usr/bin/ipmitool user test 3 20 #{'a' * 20}"),
          )
        end
      end

      context 'with a password longer than IPMI allows' do
        let(:params) { super().merge(password: 'a' * 21) }

        it { is_expected.to compile.and_raise_error(%r{password}) }
      end

      { 1 => 'CALLBACK', 2 => 'USER', 3 => 'OPERATOR', 4 => 'ADMINISTRATOR' }.each do |privilege, text|
        context "with privilege => #{privilege}" do
          let(:params) { super().merge(privilege: privilege) }

          it do
            is_expected.to contain_exec('ipmi_user_priv_admin').with(
              command: "/usr/bin/ipmitool channel setaccess 1 3 callin=on ipmi=on link=on privilege=#{privilege}",
              unless: "/usr/bin/ipmitool channel getaccess 1 3 | grep '^Privilege Level.*: #{text}$'",
            )
          end
        end
      end

      %w[absent disabled].each do |ensure_value|
        context "with ensure => #{ensure_value}" do
          let(:params) { super().merge(ensure: ensure_value) }

          it do
            is_expected.to contain_exec('ipmi_user_revoke_admin').with(
              command: '/usr/bin/ipmitool channel setaccess 1 3 callin=off ipmi=off link=off privilege=15',
              unless: "/usr/bin/ipmitool channel getaccess 1 3 | grep '^Privilege Level.*: NO ACCESS$'",
            ).that_notifies('Exec[ipmi_user_disable_sol_admin]')
          end

          it do
            is_expected.to contain_exec('ipmi_user_disable_admin').with(
              command: '/usr/bin/ipmitool user disable 3',
              unless: "/usr/bin/ipmitool channel getaccess 1 3 | grep '^Enable Status.*: disabled$'",
            ).that_notifies('Exec[ipmi_user_disable_sol_admin]')
          end

          it do
            is_expected.to contain_exec('ipmi_user_disable_sol_admin').with(
              command: '/usr/bin/ipmitool sol payload disable 1 3',
              refreshonly: true,
            )
          end

          it { is_expected.to have_exec_resource_count(3) }
        end
      end
    end
  end
end
