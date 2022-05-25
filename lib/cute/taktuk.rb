module Cute
  # Cute::TakTuk is a library for controlling the execution of commands in
  # multiple machines using taktuk tool.
  # It exposes an API similar to that of Net::SSH:Multi, making it simpler to
  # adapt to scripts designed with Net::SSH::Multi.
  # It simplifies the use of taktuk by automating the generation of large command line parameters.
  #
  #       require 'cute/taktuk'
  #
  #       results = {}
  #       Cute::TakTuk.start(['host1','host2','host3'],:user => "root") do |tak|
  #            tak.exec("df")
  #            results = tak.exec!("hostname")
  #            tak.exec("ls -l")
  #            tak.exec("sleep 20")
  #            tak.loop()
  #            tak.exec("tar xvf -")
  #            tak.input(:file => "test_file.tar")
  #       end
  #       puts results
  #
  # = Understanding {TakTuk::TakTuk#exec exec} and {TakTuk::TakTuk#exec! exec!}
  #
  # This section explains the differences between {TakTuk::TakTuk#exec exec} and {TakTuk::TakTuk#exec! exec!} with
  # several examples.
  # == Example 1
  #
  #       Cute::TakTuk.start(['host1','host2','host3'],:user => "root") do |tak|
  #            tak.exec("df")
  #            tak.exec("ls -l")
  #            tak.exec("sleep 20")
  #            tak.exec("tar xvf file.tar")
  #       end
  #
  # In the previous example all the commands will be executed concurrently on each host*.
  # This will be equivalent to execute the following sequence in bash:
  #
  #       $ df &
  #       $ ls -l &
  #       $ sleep 20 &
  #       $ tar xvf file.tar &
  #       $ wait
  #
  # The {Cute::TakTuk#start start} method waits for all commands, it performs a {TakTuk::TakTuk#loop loop()} implicitly.
  # This implicit {TakTuk::TakTuk#loop loop()} has the same behaviour as the 'wait' command in bash.
  # == Example 2
  #       Cute::TakTuk.start(['host1','host2','host3'],:user => "root") do |tak|
  #            tak.exec("df")
  #            tak.exec("ls -l")
  #            tak.loop()
  #            tak.exec("sleep 20")
  #            tak.exec("tar xvf file.tar")
  #       end
  # This will execute the two first comamnds concurrently and then the remaining commands concurrently.
  # It is equivalent to execute the following sequence in bash:
  #       $ df &
  #       $ ls -l &
  #       $ wait
  #       $ sleep 20 &
  #       $ tar xvf file.tar &
  #       $ wait
  # == Example 3
  #       Cute::TakTuk.start(['host1','host2','host3'],:user => "root") do |tak|
  #            tak.exec("df")
  #            tak.exec("ls -l")
  #            tak.exec!("sleep 20")
  #            tak.exec("tar xvf file.tar")
  #       end
  #
  # Notice that we use now the {TakTuk::TakTuk#exec! exec!} method
  # which will wait for the previous commands and then it will block until the command finishes.
  # It is equivalent to execute the following sequence in bash:
  #       $ df &
  #       $ ls -l &
  #       $ wait
  #       $ sleep 20 &
  #       $ wait
  #       $ tar xvf file.tar &
  #       $ wait
  # You can go directly to the documentation of the mentioned methods {TakTuk::TakTuk#exec exec},
  # {TakTuk::TakTuk#exec! exec!} and other useful methods such as: {TakTuk::TakTuk#put put}, {TakTuk::TakTuk#input input}, etc.
  # @see http://taktuk.gforge.inria.fr/.
  # @see TakTuk::TakTuk TakTuk Class for more documentation.
  module TakTuk

    #
    # Execution samples:
    #
    #     taktuk('hostfile',:connector => 'ssh -A', :self_propagate => true).broadcast_exec['hostname'].run!
    #
    #     taktuk(['node-1','node-2'],:dynamic => 3).broadcast_put['myfile']['dest'].run!
    #
    #     taktuk(nodes).broadcast_exec['hostname'].seq!.broadcast_exec['df'].run!
    #
    #     taktuk(nodes).broadcast_exec['cat - | fdisk'].seq!.broadcast_input_file['fdiskdump'].run!
    #
    #     tak = taktuk(nodes)
    #     tak.broadcast_exec['hostname']
    #     tak.seq!.broadcast_exec['df']
    #     tak.streams[:output] => OutputStream.new(Template[:line,:rank]),
    #     tak.streams[:info] => ConnectorStream.new(Template[:command,:line])
    #     tak.run!
    #
    def self.taktuk(*args)
      TakTuk.new(*args)
    end

    # It instantiates a new {TakTuk::TakTuk}.
    # If a block is given, a {TakTuk::TakTuk} object will be yielded to the block and automatically closed when the block finishes.
    # Otherwise a {TakTuk::TakTuk} object will be returned.
    # @param host_list [Array] list of hosts where taktuk will execute commands on.
    # @param [Hash] opts Options to be directly passed to the {TakTuk::TakTuk} object.
    # @option opts [String] :user Sets the username to login into the machines.
    # @option opts [String] :connector Defines the connector command used to contact the machines.
    # @option opts [Array] :keys SSH keys to be used for connecting to the machines.
    # @option opts [Fixnum] :port SSH port to be used for connecting to the machines.
    # @option opts [String] :config SSH configuration file
    # @option opts [String] :gateway Specifies a forward only node
    def self.start(host_list, opts={})
      taktuk_cmd = TakTuk.new(host_list, opts)
      if block_given?
        begin
          yield  taktuk_cmd
          taktuk_cmd.loop unless taktuk_cmd.commands.empty?
          taktuk_cmd.free! if taktuk_cmd
        end
      else
        return taktuk_cmd
      end
    end

    # Parses the output generated by taktuk
    # @api private
    class Stream

      attr_reader :types

      SEPARATOR = '/'
      SEPESCAPED = Regexp.escape(SEPARATOR)
      IP_REGEXP = "(?:(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}"\
        "(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"
      DOMAIN_REGEXP = "(?:(?:[a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*"\
        "(?:[A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])"
      HOSTNAME_REGEXP = "#{IP_REGEXP}|#{DOMAIN_REGEXP}"

      def initialize(types=[])
        @types = types
      end


      def parse(string)

        results = {}
        if string and !string.empty?
#          regexp = /^(output)#{SEPESCAPED}(#{HOSTNAME_REGEXP})#{SEPESCAPED}(.+)$/
          regexp = /^(#{HOSTNAME_REGEXP})#{SEPESCAPED}(.[a-z]*)#{SEPESCAPED}(.+)$/
          string.each_line do |line|
            if regexp =~ line
              hostname = Regexp.last_match(1)
              stream_type = Regexp.last_match(2).to_sym
              value_tmp = treat_value(Regexp.last_match(3))
              value =  value_tmp.is_i? ? value_tmp.to_i : value_tmp
              results[hostname] ||= {}
              if results[hostname][stream_type].nil? then
                results[hostname][stream_type] =  value
              else
                if value.is_a?(String) then
                  results[hostname][stream_type]+="\n" + value
                else
                  # This is for adding status codes
                  results[hostname][stream_type]= [results[hostname][stream_type], value]
                  results[hostname][stream_type].flatten!

                end
              end
            end
          end
        end
        return results

      end

      # Return just the value 0:(.*)
      def treat_value(string)
        tmp = string.split(":",2)
        return tmp[1].nil? ? "" : tmp[1]
      end

      def to_cmd
        # "\"$type#{SEPARATOR}$host#{SEPARATOR}$start_date#{SEPARATOR}$line\\n\""
        # We put "0:" before $line only for performance issues when executing the regex
        "\"$host#{SEPARATOR}$type#{SEPARATOR}0:$line\\n\""

      end
    end

    # Parses the output generated by the state template
    # @api private
    class StateStream < Stream
      STATES = {
                :error => {
                           3 => 'connection failed',
                           5 => 'connection lost',
                           7 => 'command failed',
                           9 => 'numbering update failed',
                           11 => 'pipe input failed',
                           14 => 'file reception failed',
                           16 => 'file send failed',
                           17 => 'invalid target',
                           18 => 'no target',
                           20 => 'invalid destination',
                           21 => 'destination not available anymore',
                          },
                :progress => {
                              0 => 'taktuk is ready',
                              1 => 'taktuk is numbered',
                              4 => 'connection initialized',
                              6 => 'command started',
                              10 => 'pipe input started',
                              13 => 'file reception started',
                             },
                :done => {
                          2 => 'taktuk terminated',
                          8 => 'command terminated',
                          12 => 'pipe input terminated',
                          15 => 'file reception terminated',
                          19 => 'message delivered',
                         }
               }

      def initialize(template)
        super(:state,template)
      end

      # type can be :error, :progress or :done
      def self.check?(type,state)
        return nil unless STATES[type]
        state = state.strip

        begin
          nb = Integer(state)
          STATES[type].keys.include?(nb)
        rescue
          STATES[type].values.include?(state.downcase!)
        end
      end

      def self.errmsg(nb)
        STATES.each_value do |typeval|
          return typeval[nb] if typeval[nb]
        end
      end
    end

    # Validates taktuk options
    # @api private
    class Options < Hash
      TAKTUK_VALID = [
                      'begin-group', 'connector', 'dynamic', 'end-group', 'machines-file',
                      'login', 'machine', 'self-propagate', 'dont-self-propagate',
                      'args-file', 'gateway', 'perl-interpreter', 'localhost',
                      'send-files', 'taktuk-command', 'path-value', 'command-separator',
                      'escape-character', 'option-separator', 'output-redirect',
                      'worksteal-behavior', 'time-granularity', 'no-numbering', 'timeout',
                      'cache-limit', 'window','window-adaptation','not-root','debug'
                     ]
      WRAPPER_VALID = [ 'streams', 'port', 'keys', 'user', 'config' ] # user is an alias for login

      def check(optname)
        ret = optname.to_s.gsub(/_/,'-').strip
        raise ArgumentError.new("Invalid TakTuk option '--#{ret}'") unless TAKTUK_VALID.include?(ret)
        ret
      end

      def to_cmd

        self[:login] = self[:user] if keys.include?(:user)
        self.keys.inject([]) do |ret,opt|
          if not WRAPPER_VALID.include?(opt.to_s) then
            ret << "--#{check(opt)}"
            if self[opt]
              if self[opt].is_a?(String)
                ret << self[opt] unless self[opt].empty?
              else
                ret << self[opt].to_s
              end
            end
          end
          ret
        end
      end
    end

    # Generates a taktuk CLI compatible host list
    # @api private
    class Hostlist
      def initialize(hostlist)
        @hostlist=hostlist
      end

      def free
        @hostlist = nil
      end

      def exclude(node)
        @hostlist.remove(node) if @hostlist.is_a?(Array)
      end

      def to_cmd
        ret = []
        if @hostlist.is_a?(Array)
          @hostlist.each do |host|
            ret << '-m'
            ret << host
          end
        elsif @hostlist.is_a?(String)
          ret << '-f'
          ret << @hostlist
        end
        ret
      end

      def to_a
        if @hostlist.is_a?(Array)
          @hostlist
        elsif @hostlist.is_a?(String)
          raise "Hostfile does not exist" unless File.exist?(@hostlist)
          File.read(@hostlist).split("\n").uniq
        end
      end
    end

    # Validates the commands accepted by taktuk
    # @api private
    class Commands < Array
      TOKENS=[
              'broadcast', 'downcast', 'exec', 'get', 'put', 'input', 'data',
              'file', 'pipe', 'close', 'line', 'target', 'kill', 'message',
              'network', 'state', 'cancel', 'renumber', 'update', 'option',
              'synchronize', 'taktuk_perl', 'quit', 'wait', 'reduce'
             ]

      def <<(val)
        raise ArgumentError.new("'Invalid TakTuk command '#{val}'") unless check(val)
        super(val)
      end

      def check(val)
        if val =~ /^-?\[.*-?\]$|^;$/
          true
        elsif val.nil? or val.empty?
          false
        else
          tmp = val.split(' ',2)
          return false unless valid?(tmp[0])
          if !tmp[1].nil? and !tmp[1].empty?
            check(tmp[1])
          else
            true
          end
        end
      end

      def valid?(value)
        TOKENS.each do |token|
          return true if token =~ /^#{Regexp.escape(value)}.*$/
        end
        return false
      end

      def to_cmd
        self.inject([]) do |ret,val|
          if val =~ /^\[(.*)\]$/
            ret + ['[',Regexp.last_match(1).strip,']']
          else
            ret + val.split(' ')
          end
        end
      end
    end

    # This class wraps the command TakTuk and generates automatically
    # the long CLI options for taktuk command.
    class TakTuk
      attr_accessor :streams,:binary
      attr_reader :stdout,:stderr,:status, :args, :exec_cmd, :commands

      VALID_STREAMS = [:output, :error, :status, :connector, :state, :info, :message, :taktuk ]

      def initialize(hostlist,options = {:connector => 'ssh'})
        raise ArgumentError.new("options parameter has to be a hash") unless options.is_a?(Hash)

        @binary = 'taktuk'
        @options = Options[options.merge({ :streams => [:output, :error, :status ]})] if options[:streams].nil?
        @options.merge!({:connector => 'ssh'}) if options[:connector].nil?
        @streams = Stream.new(@options[:streams])
        # @streams = Stream.new([:output,:error,:status, :state])

        @hostlist = Hostlist.new(hostlist)
        @commands = Commands.new

        @args = nil
        @stdout = nil
        @stderr = nil
        @status = nil

        @exec_cmd = nil
        @curthread = nil
        @connector = @options[:connector]
      end

      def run!(opts = {})
        @curthread = Thread.current
        @args = []
        @args += @options.to_cmd

        @streams.types.each{ |name|
          @args << '-o'
          @args << "#{name}=#{@streams.to_cmd}"
        }

        connector = build_connector
        @args += ["--connector", "#{connector}"] unless connector.nil?

        @args += @hostlist.to_cmd
        @args += @commands.to_cmd

        hosts = @hostlist.to_a
        outputs_size = opts[:outputs_size] || 0
        @exec_cmd = Cute::Execute[@binary,*@args].run!(
                                             :stdout_size => outputs_size * hosts.size,
                                             :stderr_size => outputs_size * hosts.size,
                                             :stdin => false
                                                )
        @status, @stdout, @stderr, emptypipes = @exec_cmd.wait({:checkstatus=>false})

        unless @status.success?
          @curthread = nil
          return false
        end

        unless emptypipes
          @curthread = nil
          @stderr = "Too much data on the TakTuk command's stdout/stderr"
          return false
        end

        results = @streams.parse(@stdout)
        @curthread = nil

        results
      end

      # It executes the commands so far stored in the @commands variable
      # and reinitialize the variable for post utilization.
      def loop ()
        run!()
        $stdout.print(@stdout)
        $stderr.print(@stderr)
        @commands = Commands.new
      end

      def kill!()
        unless @exec.nil?
          @exec.kill
          @exec = nil
        end
        free!()
      end

      def free!()
        @binary = nil
        @options = nil
        # if @streams
        #   @streams.each_value do |stream|
        #     stream.free if stream
        #     stream = nil
        #   end
        # end
        @hostlist.free if @hostlist
        @hostlist = nil
        @commands = nil
        @args = nil
        @stdout = nil
        @stderr = nil
        @status = nil
        @exec = nil
        @curthread = nil
      end

      def raw!(string)
        @commands << string.strip
        self
      end

      # It executes a command on multiple hosts.
      # All output is printed via *stdout* and *stderr*.
      # Note that this method returns immediately,
      # and requires a call to the loop method in order
      # for the command to actually execute.
      # The execution is done by TakTuk using broadcast exec.
      # @param [String] cmd Command to execute.
      #
      # = Example
      #
      #  tak.exec("hostname")
      #  tak.exec("mkdir ~/test")
      #  tak.loop() # to trigger the execution of commands
      def exec(cmd)
        mode = "broadcast"
        @commands << "#{mode} exec"
        @commands << "[ #{cmd} ]"
        @commands << ';' # TakTuk command separator
      end

      # It transfers a file to all the machines in parallel.
      # @param [String] source Source path for the file to be transfer
      # @param [String] dest Destination path for the file to be transfer
      #
      # = Example
      #
      #    tak.put("hosts.allow_template", "/etc/hosts.allow")
      #
      def put(source,dest)
        mode = "broadcast"
        @commands << "#{mode} put"
        @commands << "[ #{source} ]"
        @commands << "[ #{dest} ]"
        @commands << ';' # TakTuk command separator
      end


      # It executes a command on multiple hosts capturing the output,
      # and other information related with the execution.
      # It blocks until the command finishes.
      # @param [String] cmd Command to be executed
      # @return [Hash] Result data structure
      #
      # = Example
      #
      #    tak.exec!("uname -r") #=> {"node2"=>{:output=>"3.2.0-4-amd64", :status=>0}, "node3"=>{:output=>"3.2.0-4-amd64", :status=>0}, ...}
      #
      def exec!(cmd)
        loop() unless @commands.empty?
        exec(cmd)
        results = run!()
        @commands = Commands.new
        return results
      end

      # Manages the taktuk command input
      # @param [Hash] opts Options for the type of data
      # @option opts [String] :data Raw data to be used as the input of a command
      # @option opts [String] :filename a file to be used as the input of a command
      #
      # = Example
      #
      #    tak.exec("wc -w")
      #    tak.input(:data => "data data data data")
      #
      #    tak.exec("tar xvf -")
      #    tak.input(:file => "test_file.tar")
      def input(opts = {})
        mode = "broadcast"
        @commands << "#{mode} input #{opts.keys.first}"
        @commands << "[ #{opts.values.first} ]"
        @commands << ';'
      end


      def [](command,prefix='[',suffix=']')
        @commands << "#{prefix} #{command} #{suffix}"
        self
      end

      def method_missing(meth,*args)
        @commands << (meth.to_s.gsub(/_/,' ').strip.downcase)
        args.each do |arg|
          @commands.push(arg.strip.downcase)
        end
        self
      end

      alias close free!

      private
      # It builds a custom connector for TakTuk
      def build_connector()
        ssh_options = [:keys, :port, :config]
        connector = @connector
        if @options.keys.map{ |opt| ssh_options.include?(opt)}.any?
          connector += " -p #{@options[:port]}" if @options[:port]
          if @options[:keys]
            keys = @options[:keys].is_a?(Array) ? @options[:keys].first : @options[:keys]
            connector += " -i #{keys}"
          end
          connector += " -F #{@options[:config]}" if @options[:config]
        end
        return connector
      end

      # It is used to separate the commands, they will run in parallel.
      def seq!
        @commands << ';'
        self
      end

    end

  end
end
