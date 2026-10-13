# frozen_string_literal: true

require 'spec_helper'

describe 'ipmi facts' do
  before do
    Facter.clear
    allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
  end

  def stub_ipmitool(command, output_fixture, redirect: '2>&1')
    output = output_fixture ? File.read(File.join(__dir__, '../../fixtures/ipmitool', "#{output_fixture}.txt")) : ''
    allow(Facter::Core::Execution).to receive(:execute).with("ipmitool #{command} #{redirect}").and_return(output)
  end

  context 'with ipmitool installed' do
    before do
      allow(Facter::Core::Execution).to receive(:which).with('ipmitool').and_return('/usr/bin/ipmitool')
      stub_ipmitool('lan print 1', 'lan_print_1')
      stub_ipmitool('mc info', 'mc_info', redirect: '2>/dev/null')
      stub_ipmitool('fru print 0', 'fru_print_0', redirect: '2>/dev/null')
    end

    context 'with a user summary' do
      before do
        stub_ipmitool('user summary', 'user_summary')
        stub_ipmitool('channel getaccess 1 1', 'getaccess_anonymous_user')
        stub_ipmitool('channel getaccess 1 2', 'getaccess_fixed_user')
        stub_ipmitool('channel getaccess 1 3', 'getaccess_added_user')
        (4..10).each { |id| stub_ipmitool("channel getaccess 1 #{id}", 'getaccess_empty_user') }
      end

      it { expect(Facter.value(:ipmi_channel)).to eq(1) }
      it { expect(Facter.value(:ipmi_ipaddress)).to eq('192.168.0.37') }
      it { expect(Facter.value(:ipmi_ipaddress_source)).to eq('DHCP Address') }
      it { expect(Facter.value(:ipmi_subnet_mask)).to eq('255.255.255.0') }
      it { expect(Facter.value(:ipmi_macaddress)).to eq('3c:a8:2a:9f:9a:92') }
      it { expect(Facter.value(:ipmi_gateway)).to eq('192.168.0.1') }
      it { expect(Facter.value(:ipmi_max_users)).to eq(10) }

      it 'lists users that are enabled, fixed or named' do
        expect(Facter.value(:ipmi_users)).to eq(
          [
            { 'id' => 1, 'username' => '', 'fixed_name' => true, 'enabled' => false },
            { 'id' => 2, 'username' => 'ADMIN', 'fixed_name' => true, 'enabled' => true, 'privilege' => 4 },
            { 'id' => 3, 'username' => 'foreman', 'fixed_name' => false, 'enabled' => true, 'privilege' => 2 },
          ],
        )
      end

      it 'keeps management controller fields that have a value' do
        expect(Facter.value(:ipmi_mc_info)).to eq(
          'device_id' => '32',
          'device_revision' => '1',
          'firmware_revision' => '1.73',
          'ipmi_version' => '2.0',
          'manufacturer_id' => '10876',
          'manufacturer_name' => 'Supermicro',
          'product_id' => '6929 (0x1b11)',
          'product_name' => 'Unknown (0x1B11)',
          'device_available' => 'yes',
          'provides_device_sdrs' => 'no',
        )
      end

      it 'keeps FRU fields that have a value' do
        expect(Facter.value(:ipmi_fru)).to eq(
          'chassis_type' => 'Other',
          'chassis_part_number' => 'CSE-505-203B',
          'chassis_serial' => 'C5050LK26NP0123',
          'board_mfg_date' => 'Mon Jan  1 00:00:00 1996',
          'board_mfg' => 'Supermicro',
          'board_serial' => 'ZM19AS012345',
          'board_part_number' => 'X11SCL-IF',
          'product_manufacturer' => 'Supermicro',
          'product_part_number' => 'SYS-5019C-L',
          'product_serial' => 'S392000X9123456',
        )
      end

      context 'when the BMC returns no inventory' do
        before do
          stub_ipmitool('mc info', nil, redirect: '2>/dev/null')
          stub_ipmitool('fru print 0', nil, redirect: '2>/dev/null')
        end

        it { expect(Facter.value(:ipmi_mc_info)).to be_nil }
        it { expect(Facter.value(:ipmi_fru)).to be_nil }
      end

      context 'on a non-Linux kernel' do
        before { allow(Facter.fact(:kernel)).to receive(:value).and_return('windows') }

        it { expect(Facter.value(:ipmi_channel)).to be_nil }
        it { expect(Facter.value(:ipmi_macaddress)).to be_nil }
        it { expect(Facter.value(:ipmi_users)).to be_nil }
        it { expect(Facter.value(:ipmi_fru)).to be_nil }
      end
    end

    context 'without a user summary' do
      before { stub_ipmitool('user summary', 'user_summary_unavailable') }

      it { expect(Facter.value(:ipmi_macaddress)).to eq('3c:a8:2a:9f:9a:92') }
      it { expect(Facter.value(:ipmi_max_users)).to be_nil }
      it { expect(Facter.value(:ipmi_users)).to be_nil }
    end
  end

  context 'without ipmitool installed' do
    before { allow(Facter::Core::Execution).to receive(:which).with('ipmitool').and_return(nil) }

    it { expect(Facter.value(:ipmi_channel)).to eq(1) }
    it { expect(Facter.value(:ipmi_ipaddress)).to be_nil }
    it { expect(Facter.value(:ipmi_max_users)).to be_nil }
    it { expect(Facter.value(:ipmi_users)).to be_nil }
    it { expect(Facter.value(:ipmi_mc_info)).to be_nil }
  end
end
