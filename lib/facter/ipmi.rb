# frozen_string_literal: true

# IPMI facts, in a format compatible with The Foreman
#
# Sending these facts to a Puppet Server equipped with Foreman
# will cause the latter to create the BMC interfaces the next time the
# Puppet agent runs. One then only has to manually add the access
# credentials, and presto, you can run basic IPMI actions (e.g. reboot
# to PXE) from The Foreman's web UI.
#
# === Fact Format (for Foreman compatibility)
#
#     ipmi_ipaddress = 192.168.101.1
#     ipmi_subnet_mask = 255.255.255.0
#     ...

@channel_id = 1

def load_net_facts
  output = Facter::Core::Execution.execute("ipmitool lan print #{@channel_id} 2>&1")
  output.each_line do |line|
    case line.strip
    when %r{^IP Address\s*:\s+(\S.*)}
      add_ipmi_fact('ipaddress', Regexp.last_match(1))
    when %r{^IP Address Source\s*:\s+(\S.*)}
      add_ipmi_fact('ipaddress_source', Regexp.last_match(1))
    when %r{^Subnet Mask\s*:\s+(\S.*)}
      add_ipmi_fact('subnet_mask', Regexp.last_match(1))
    when %r{^MAC Address\s*:\s+(\S.*)}
      add_ipmi_fact('macaddress', Regexp.last_match(1))
    when %r{^Default Gateway IP\s*:\s+(\S.*)}
      add_ipmi_fact('gateway', Regexp.last_match(1))
    end
  end
end

def load_user_facts
  users = []
  max_id = max_users
  return unless max_id&.positive?

  add_ipmi_fact 'max_users', max_id

  (1..max_id).to_a.each do |id|
    username = '' # Anonymous users exist
    privilege = nil
    fixed_name = nil
    enabled = nil
    output = Facter::Core::Execution.execute("ipmitool channel getaccess #{@channel_id} #{id} 2>&1")
    output.each_line do |line|
      case line.strip
      when %r{^User Name\s*:\s*(\S.*)}
        username = Regexp.last_match(1)
      when %r{^Fixed Name\s*:\s*(\S.*)}
        case Regexp.last_match(1)
        when 'Yes'
          fixed_name = true
        when 'No'
          fixed_name = false
        end
      when %r{^Enable Status\s*:\s*(\S.*)}
        case Regexp.last_match(1)
        when 'enabled'
          enabled = true
        when 'disabled'
          enabled = false
        end
      when %r{^Privilege Level\s*:\s*(\S.*)}
        case Regexp.last_match(1)
        when 'CALLBACK'
          privilege = 1
        when 'USER'
          privilege = 2
        when 'OPERATOR'
          privilege = 3
        when 'ADMINISTRATOR'
          privilege = 4
        end
      end
    end

    next if !enabled && !fixed_name && username.empty?

    user = {
      id: id,
      username: username,
      fixed_name: fixed_name,
      enabled: enabled,
    }
    user[:privilege] = privilege if privilege
    users << user
  end

  add_ipmi_fact 'users', users
end

def max_users
  output = Facter::Core::Execution.execute('ipmitool user summary 2>&1')
  output.each_line do |line|
    return Regexp.last_match(1).to_i if line =~ %r{^Maximum IDs\s*:\s*(\d+)}
  end
  nil
end

def load_inventory_facts
  { 'mc_info' => 'mc info', 'fru' => 'fru print 0' }.each do |name, command|
    fields = ipmitool_fields(command)
    add_ipmi_fact(name, fields) unless fields.empty?
  end
end

# stderr is dropped because error messages also hold 'key: value' pairs
def ipmitool_fields(command)
  output = Facter::Core::Execution.execute("ipmitool #{command} 2>/dev/null")
  output.each_line.filter_map do |line|
    key, value = line.split(':', 2).map(&:strip)
    [key.downcase.gsub(%r{\W+}, '_'), value] unless value.nil? || value.empty?
  end.to_h
end

def add_ipmi_fact(name, value)
  Facter.add("ipmi_#{name}") do
    confine kernel: 'Linux'
    setcode do
      value
    end
  end
end

add_ipmi_fact 'channel', @channel_id
if Facter::Core::Execution.which('ipmitool')
  load_net_facts
  load_user_facts
  load_inventory_facts
end
