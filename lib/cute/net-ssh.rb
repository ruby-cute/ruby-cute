# Extends the Net SSH modules

# This monkey patch extends the capabilities of the module Multi
module Net; module SSH; module Multi

  # sets logger to be used by net-ssh-multi module
  def self.logger= v
    @logger = v
  end

  # @return logger
  def self.logger
    @logger
  end

module SessionActions

  # Monkey patch for the exec method.
  # It adds stdout and stderr management for debugging purposes.
  # @see http://net-ssh.github.io/net-ssh-multi/classes/Net/SSH/Multi/SessionActions.html More information about exec method.
  # @return [Hash] the host names and their associated stdout
  def exec(command, &block)

    outs = {}
    errs = {}

    main =open_channel do |channel|
      channel.exec(command) do |ch, success|
        raise "could not execute command: #{command.inspect} (#{ch[:host]})" unless success
        Multi.logger.debug("Executing #{command} on [#{ch.connection.host}]")

        channel.on_data do |ch, data|
          if block
            block.call(ch, :stdout, data)
          else
            outs[ch.connection.host] = [] unless outs[ch.connection.host]
            outs[ch.connection.host] << data.strip

            Multi.logger.debug("[#{ch.connection.host}] #{data.strip}")
          end
        end
        channel.on_extended_data do |ch, type, data|
          if block
            block.call(ch, :stderr, data)
          else
            errs[ch.connection.host] = [] unless errs[ch.connection.host]
            errs[ch.connection.host] << data.strip
            Multi.logger.debug("[#{ch.connection.host}] #{data.strip}")
          end
        end
        channel.on_request("exit-status") do |ch, data|
          ch[:exit_status] = data.read_long
          Multi.logger.debug("Status returned #{ch[:exit_status]}")
          if ch[:exit_status] != 0
            Multi.logger.debug("execution of '#{command}' on #{ch.connection.host}
                            failed with return status #{ch[:exit_status].to_s}")
            Multi.logger.debug("--- stdout dump ---")
            outs[ch.connection.host].each {|out| Multi.logger.debug(out)} if outs[ch.connection.host]
            Multi.logger.debug("--stderr dump ---")
            errs[ch.connection.host].each {|err| Multi.logger.debug(err)} if errs[ch.connection.host]
          end
        end
        # need to decide severity level if the command fails
      end
    end
    main.wait # we have to wait the channel otherwise we will have void results
    return outs#,errs
  end

end
end; end; end
