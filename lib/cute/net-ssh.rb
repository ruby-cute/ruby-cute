require 'net/ssh/multi'
require 'logger'

module Net; module SSH

# The Net::SSH::Multi aims at executing commands in parallel over a set of machines using the SSH protocol.
# One of the advantage of this module over {Cute::TakTuk::TakTuk TakTuk} is that it allows to create groups, for example:
#
#     Net::SSH::Multi.start do |session|
#
#        session.group :coord do
#             session.use("root@#{coordinator}")
#        end
#
#        session.group :nodes do
#              nodelist.each{ |node| session.use("root@#{node}")}
#        end
#
#        # test connection
#        session.with(:coord).exec! "hostname"
#        session.with(:nodes).exec! "hostname"
#
#        # Check nfs paths
#        tmp = session.exec! "ls -a #{ENV['HOME']}"
#
#        # generating ssh password less connection
#        session.exec! "cat .ssh/id_rsa.pub >> .ssh/authorized_keys"
#     end
#
# However, with large set of nodes SSH it is limited an inefficient,
# for those cases the best option will be {Cute::TakTuk::TakTuk TakTuk}.
# For complete documentation please take a look at
# {http://net-ssh.github.io/net-ssh-multi/ Net::SSH::Multi}.
# One of the disadvantages of {http://net-ssh.github.io/net-ssh-multi/ Net::SSH::Multi} is that
# it does not allow to capture the output (stdout, stderr and status) of executed commands.
# Ruby-Cute ships a monkey patch that extends the aforementioned module by adding the method
# {Net::SSH::Multi::SessionActions#exec! exec!}
# which blocks until the command finishes and captures the output (stdout, stderr and status).
#
#     require 'cute/net-ssh'
#
#     results = {}
#     Net::SSH::Multi.start do |session|
#
#        # define the servers we want to use
#        session.use 'user1@host1'
#        session.use 'user2@host2'
#
#        session.exec "uptime"
#        session.exec "df"
#        # execute command, blocks and capture the output
#        results = session.exec! "date"
#        # execute commands on a subset of servers
#        session.exec "hostname"
#     end
#     puts results #=> {"node3"=>{:stdout=>"Wed Mar 11 12:38:11 UTC 2015", :status=>0},
#                  #    "node1"=>{:stdout=>"Wed Mar 11 12:38:11 UTC 2015", :status=>0}, ...}
#
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
  # It executes a command on multiple hosts capturing their associated output (stdout, stderr and status).
  # It blocks until the command finishes returning the resulting output as a Hash.
  # It uses a logger for debugging purposes.
  # @see http://net-ssh.github.io/net-ssh-multi/classes/Net/SSH/Multi/SessionActions.html More information about exec method.
  # @return [Hash] result Hash stdout, stderr and status of executed commands
  #
  # = Example
  #
  #    session.exec!("date") #=> {"node3"=>{:stdout=>"Wed Mar 11 12:38:11 UTC 2015", :status=>0},
  #                          #    "node1"=>{:stdout=>"Wed Mar 11 12:38:11 UTC 2015", :status=>0}, ...}
  #
  #    session.exec!("cmd") #=> {"node4"=>{:stderr=>"bash: cmd: command not found", :status=>127},
  #                         #    "node3"=>{:stderr=>"bash: cmd: command not found", :status=>127}, ...}
  #
  def exec!(command, &block)

    results = {}

    main =open_channel do |channel|
      channel.exec(command) do |ch, success|
        raise "could not execute command: #{command.inspect} (#{ch[:host]})" unless success
        Multi.logger.debug("Executing #{command} on [#{ch.connection.host}]")

        results[ch.connection.host] ||= {}

        channel.on_data do |ch, data|
          if block
            block.call(ch, :stdout, data)
          else
            results[ch.connection.host][:stdout] = data.strip
            Multi.logger.debug("[#{ch.connection.host}] #{data.strip}")
          end
        end
        channel.on_extended_data do |ch, type, data|
          if block
            block.call(ch, :stderr, data)
          else
            results[ch.connection.host][:stderr] = data.strip
            Multi.logger.debug("[#{ch.connection.host}] #{data.strip}")
          end
        end
        channel.on_request("exit-status") do |ch, data|
          ch[:exit_status] = data.read_long
          results[ch.connection.host][:status] = ch[:exit_status]
          if ch[:exit_status] != 0
            Multi.logger.info("execution of '#{command}' on #{ch.connection.host}
                            failed with return status #{ch[:exit_status].to_s}")
            if results[ch.connection.host][:stdout]
              Multi.logger.info("--- stdout dump ---")
              Multi.logger.info(results[ch.connection.host][:stdout])
            end

            if  results[ch.connection.host][:stderr]
              Multi.logger.info("--stderr dump ---")
              Multi.logger.info(results[ch.connection.host][:stderr])
            end
          end
        end
        # need to decide severity level if the command fails
      end
    end
    main.wait # we have to wait the channel otherwise we will have void results
    return results
  end

end
end; end; end
