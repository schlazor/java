unified_mode true

property :java_location,
          String,
          description: 'Java installation location'

property :bin_cmds,
          Array,
          description: 'Array of Java tool names to set or unset alternatives on'

property :default,
          [true, false],
          default: true,
          description: 'Whether to set the Java tools as system default. Boolean, defaults to `true`'

property :priority,
          Integer,
          default: 1061,
          description: ' Priority of the alternatives. Integer, defaults to `1061`'

property :reset_alternatives,
          [true, false],
          default: true,
          description: 'Whether to reset alternatives before setting them'

action :set do
  if new_resource.bin_cmds
    new_resource.bin_cmds.each do |cmd|
      bin_path = "/usr/bin/#{cmd}"
      alt_path = "#{new_resource.java_location}/bin/#{cmd}"
      priority = new_resource.priority

      unless ::File.exist?(alt_path)
        Chef::Log.debug "Skipping setting alternative for #{cmd}. Command #{alt_path} does not exist."
        next
      end

      Chef::Log.warn "#{alternatives_cmd} --display #{cmd} | grep #{alt_path} | grep 'priority #{priority}$'"
      alternative_exists_same_priority = shell_out("#{alternatives_cmd} --display #{cmd} | grep #{alt_path} | grep 'priority #{priority}$'").exitstatus == 0
      Chef::Log.warn "#{alternatives_cmd} --display #{cmd} | grep #{alt_path}"
      alternative_exists = shell_out("#{alternatives_cmd} --display #{cmd} | grep #{alt_path}").exitstatus == 0
      # remove alternative if priority is changed and install it with new priority
      if alternative_exists && !alternative_exists_same_priority
        converge_by("Removing alternative for #{cmd} with old priority") do
          Chef::Log.debug "Removing alternative for #{cmd} with old priority"
          Chef::Log.warn "#{alternatives_cmd} --remove #{cmd} #{alt_path}"
          remove_cmd = shell_out("#{alternatives_cmd} --remove #{cmd} #{alt_path}")
          alternative_exists = false
          unless remove_cmd.exitstatus == 0
            raise(%( remove alternative failed ))
          end
        end
      end
      # install the alternative if needed
      unless alternative_exists
        converge_by("Add alternative for #{cmd}") do
          Chef::Log.debug "Adding alternative for #{cmd}"
          if new_resource.reset_alternatives
            Chef::Log.warn "rm /var/lib/alternatives/#{cmd}"
            shell_out("rm /var/lib/alternatives/#{cmd}")
          end
          Chef::Log.warn "#{alternatives_cmd} --install #{bin_path} #{cmd} #{alt_path} #{priority}"
          install_cmd = shell_out("#{alternatives_cmd} --install #{bin_path} #{cmd} #{alt_path} #{priority}")
          unless install_cmd.exitstatus == 0
            raise(%( install alternative failed ))
          end
        end
      end

      # set the alternative if default
      next unless new_resource.default
      Chef::Log.warn "#{alternatives_cmd} --display #{cmd} | grep \"link currently points to #{alt_path}\""
      alternative_is_set = shell_out("#{alternatives_cmd} --display #{cmd} | grep \"link currently points to #{alt_path}\"").exitstatus == 0
      next if alternative_is_set
      converge_by("Set alternative for #{cmd}") do
        Chef::Log.debug "Setting alternative for #{cmd}"
        Chef::Log.warn "#{alternatives_cmd} --set #{cmd} #{alt_path}"
        set_cmd = shell_out("#{alternatives_cmd} --set #{cmd} #{alt_path}")
        unless set_cmd.exitstatus == 0
          raise(%( set alternative failed ))
        end
      end
    end
  end
end

action :unset do
  new_resource.bin_cmds.each do |cmd|
    converge_by("Remove alternative for #{cmd}") do
      shell_out("#{alternatives_cmd} --remove #{cmd} #{new_resource.java_location}/bin/#{cmd}")
    end
  end
end

action_class do
  def alternatives_cmd
    platform_family?('rhel', 'fedora', 'amazon') ? 'alternatives' : 'update-alternatives'
  end
end
