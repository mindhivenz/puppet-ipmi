# frozen_string_literal: true

require 'spec_helper'

describe 'ipmi::snmp' do
  let(:title) { 'example' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_exec('ipmi_set_snmp_1').with(
            command: '/usr/bin/ipmitool lan set 1 snmp public',
            onlyif: %(/usr/bin/test "$(ipmitool lan print 1 | grep 'SNMP Community String' | sed -e 's/.* : //g')" != "public"),
          )
        end
      end

      context 'with snmp and channel' do
        let(:params) { { snmp: 'secret', channel: 2 } }

        it do
          is_expected.to contain_exec('ipmi_set_snmp_2').with(
            command: '/usr/bin/ipmitool lan set 2 snmp secret',
            onlyif: %(/usr/bin/test "$(ipmitool lan print 2 | grep 'SNMP Community String' | sed -e 's/.* : //g')" != "secret"),
          )
        end
      end
    end
  end
end
