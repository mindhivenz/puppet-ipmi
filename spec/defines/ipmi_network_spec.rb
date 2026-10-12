# frozen_string_literal: true

require 'spec_helper'

describe 'ipmi::network' do
  let(:title) { 'example' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_exec('ipmi_set_dhcp_1').with(
            command: '/usr/bin/ipmitool lan set 1 ipsrc dhcp',
            onlyif: "/usr/bin/test $(ipmitool lan print 1 | grep 'IP Address Source' | cut -f 2 -d : | grep -c DHCP) -eq 0",
          )
        end

        it { is_expected.not_to contain_exec('ipmi_set_static_1') }
      end

      context 'with type => static' do
        let(:params) { { type: 'static', ip: '10.0.0.5', netmask: '255.255.0.0', gateway: '10.0.0.1', channel: 2 } }

        it { is_expected.not_to contain_exec('ipmi_set_dhcp_2') }

        it do
          is_expected.to contain_exec('ipmi_set_static_2').with(
            command: '/usr/bin/ipmitool lan set 2 ipsrc static',
            onlyif: "/usr/bin/test $(ipmitool lan print 2 | grep 'IP Address Source' | cut -f 2 -d : | grep -c DHCP) -eq 1",
          ).that_notifies(['Exec[ipmi_set_ipaddr_2]', 'Exec[ipmi_set_defgw_2]', 'Exec[ipmi_set_netmask_2]'])
        end

        it do
          is_expected.to contain_exec('ipmi_set_ipaddr_2').with(
            command: '/usr/bin/ipmitool lan set 2 ipaddr 10.0.0.5',
            onlyif: %(/usr/bin/test "$(ipmitool lan print 2 | grep 'IP Address  ' | sed -e 's/.* : //g')" != "10.0.0.5"),
          )
        end

        it do
          is_expected.to contain_exec('ipmi_set_defgw_2').with(
            command: '/usr/bin/ipmitool lan set 2 defgw ipaddr 10.0.0.1',
            onlyif: %(/usr/bin/test "$(ipmitool lan print 2 | grep 'Default Gateway IP' | sed -e 's/.* : //g')" != "10.0.0.1"),
          )
        end

        it do
          is_expected.to contain_exec('ipmi_set_netmask_2').with(
            command: '/usr/bin/ipmitool lan set 2 netmask 255.255.0.0',
            onlyif: %(/usr/bin/test "$(ipmitool lan print 2 | grep 'Subnet Mask' | sed -e 's/.* : //g')" != "255.255.0.0"),
          )
        end
      end
    end
  end
end
