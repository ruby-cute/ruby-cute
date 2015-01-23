require 'net/ssh/multi'
require 'logger'

module Net; module SSH

# This monkey patch extends the capabilities of the module Net::SSH::Multi.
# It adds the method exec! which blocks until the command finishes and captures the output (stdout and stderr).
#     require 'cute/net-ssh'
#
#     results = []
#     Net::SSH::Multi.start do |session|
#
#        # define the servers we want to use
#        session.use 'user1@host1'
#        session.use 'user2@host2'
#
#        session.exec "uptime"
#        session.exec "df"
#        # execute command, blocks and capture the output
#        results = session.exec! "ls -l"
#        # execute commands on a subset of servers
#        session.exec "hostname"
#     end
#     puts results
# @see Net::SSH::Multi::SessionActions for more documentation.

module Multi

  # sets logger to be used by net-ssh-multi module
  def self.logger= v
    @logger = v
  end

  # @return logger
  def self.logger
    if @logger.nil?
      @logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
    end
    @logger
  end

module SessionActions

  # Monkey patch that adds the exec! method.
  # It executes a command on multiple hosts capturing their associated output (stdout and stderr).
  # It blocks until the command finishes returning the resulting output as a Hash.
  # It adds stdout and stderr management for debugging purposes.
  # @see http://net-ssh.github.io/net-ssh-multi/classes/Net/SSH/Multi/SessionActions.html More information about exec method.
  # @return [Hash] associated output (stdout and stderr) as a Hash.
  def exec!(command, &block)

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
            if outs[ch.connection.host]
              Multi.logger.debug("--- stdout dump ---")
              outs[ch.connection.host].each {|out| Multi.logger.debug(out)}
            end

            if  errs[ch.connection.host]
              Multi.logger.debug("--stderr dump ---")
              errs[ch.connection.host].each {|err| Multi.logger.debug(err)}
            end
          end
        end
        # need to decide severity level if the command fails
      end
    end
    main.wait # we have to wait the channel otherwise we will have void results
    return {:stdout => outs,:stderr => errs}
  end

end
end; end; end
