# frozen_string_literal: true

require 'spec_helper'

describe 'ipmi facts' do
  before do
    Facter.clear
    allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
  end

  def stub_ipmitool(command, output_fixture)
    output = File.read(File.join(__dir__, '../../fixtures/ipmitool', "#{output_fixture}.txt"))
    allow(Facter::Core::Execution).to receive(:execute).with("ipmitool #{command} 2>&1").and_return(output)
  end

  context 'with ipmitool installed' do
    before do
      allow(Facter::Core::Execution).to receive(:which).with('ipmitool').and_return('/usr/bin/ipmitool')
      stub_ipmitool('lan print 1', 'lan_print_1')
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

      context 'on a non-Linux kernel' do
        before { allow(Facter.fact(:kernel)).to receive(:value).and_return('windows') }

        it { expect(Facter.value(:ipmi_channel)).to be_nil }
        it { expect(Facter.value(:ipmi_macaddress)).to be_nil }
        it { expect(Facter.value(:ipmi_users)).to be_nil }
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
  end
end
