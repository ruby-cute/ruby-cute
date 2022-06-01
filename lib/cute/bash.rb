
#
# Features a cool class to interface with Bash.
#

require 'digest'
require 'open3'

module Cute; module Bash

    class BashError < StandardError; end
    class BashTimeout < BashError; end
    class BashPaddingError < BashError; end

    class StatusError < BashError

        attr_reader :status
        attr_reader :output

        def initialize(cmd, status, output)
            super("'#{cmd}' returned with status = #{status}")
            @status = status
            @cmd = cmd
            @output = output
        end

    end

    class Bash

        def initialize(stdin, stdout, debug = false)
            @stdin = stdin
            @stdout = stdout
            @debug = debug
            @buff = ''
        end

        def parse(&block)
            return self.instance_exec(&block)
        end

        def _loop
            while true do
                x = IO::select([@stdout], [], [], 120.0)
                raise BashTimeout.new if x.nil?
                bytes = @stdout.sysread(1024)
                $stderr.write("\nBASH IN: #{bytes}\n") if @debug
                @buff << bytes
                break if yield
            end
        end

        def _nonce
            randee = 4.times.map { rand().to_s }.join('|')
            return Digest::SHA512.hexdigest(randee).to_s
        end

        def _run(cmd, _opts)
            # it's a kind of magic
            $stderr.write("\nBASH CMD: #{cmd}\n") if @debug
            nonce = _nonce()
            @stdin.write("#{cmd}; printf '%04d#{nonce}' $?\n")
            @stdin.flush
            _loop do
                @buff.include?(nonce)
            end
            raise BashPaddingError.new if !@buff.end_with?(nonce)
            output = @buff
            @buff = ''
            # treat the output
            output.slice!(-nonce.length..-1)
            status = output.slice!(-4..-1)
            raise "Status #{status} > 255?" if status.slice(0..0) != '0'
            return output, status.to_i
        end

        def _run_block(cmd, _opts)
            @stdin.write("#{cmd}; printf '%04d#{nonce}' $?\n")
        end

        def _extend(path, suffix)
            path = path.chomp('/') if path.end_with?('/')
            return path + suffix
        end

        def _unlines(s)
            return s.lines.map { |l| l.chomp("\n") }
        end

        def _escape(args)
            return args.map { |x| "'#{x}'" }.join(' ')
        end

        # TESTING METHODS

        def assert(condition, msg = 'Assertion error')
            raise msg if condition != true
        end

        # PUBLIC METHODS

        def export(name, value)
            run("export #{name}=#{value}")
        end

        def run(cmd, opts = {})
            out, status = _run(cmd, opts)
            raise StatusError.new(cmd, status, out) if status != 0
            return out
        end

        def run_status(cmd, opts = {})
            _out, status = _run(cmd, opts)
            return status
        end

        def cd(path)
            run("cd #{path}")
        end

        def ls
            run("ls -1").lines.map { |line| line.chomp("\n") }
        end

        def pwd
            run("pwd").strip
        end

        def untar(name, where = nil)
            if where.nil?
                run("tar xvf #{name}")
            else
                run("tar -C #{where} -xvf #{name}")
            end
        end

        def echo(text)
            run("echo #{text}")
        end

        def bc(text)
            run("echo '#{text}' | bc").strip
        end

        def cp(a, b)
            run("cp #{a} #{b}")
        end

        def mv(a, b)
            run("mv #{a} #{b}")
        end

        def rm(*args)
            run("rm #{_escape(args)}")
        end

        def remove_dirs(path)
            rm "-rf", path
        end

        def build
            # builds a standard Unix software
            run("./configure")
            run("make")
        end

        def abspath(path)
            run("readlink -f #{path}").strip
        end

        def build_tarball(tarball, path)
            # builds a tarball containing a std Unix software
            tarball = abspath(tarball)
            path = abspath(path)
            remove_dirs(path)
            tmp = _extend(path, '-tmp')
            remove_dirs(tmp)
            make_dirs(tmp)
            untar(tarball, tmp)
            cd tmp
            # we are in the temp dir
            if exists('./configure')
                cd '/'
                mv tmp, path
            else
                ds = dirs()
                raise 'Too many dirs?' if ds.length != 1
                mv ds.first, path
                cd '/'
                remove_dirs(tmp)
            end
            cd path
            build
        end

        def tmp_file
            return run('mktemp').strip
        end

        def save_machines(machines, path = nil)
            path = tmp_file if path.nil?
            append_lines(path, machines.map { |m| m.to_s })
            return path
        end

        def mpirun(machines, params)
            machines = save_machines(machines) if machines.is_a?(Array)
            return run("mpirun --mca btl ^openib -machinefile #{machines} #{params}")
        end

        def join(*args)
            return File.join(*args)
        end

        def exists(path)
            run_status("[[ -e #{path} ]]") == 0
        end

        def make_dirs(path)
            run("mkdir -p #{path}")
        end

        def mkdir(path)
            run("mkdir #{path}") unless exists(path)  # TODO: this changes semantics of mkdir...
        end

        def files(ignore = true, type = 'f')
            fs = run("find . -maxdepth 1 -type #{type}")
            fs = _unlines(fs).reject { |f| f == '.' }.map { |f| f[2..-1] }
            fs = fs.reject { |f| f.end_with?('~') or f.start_with?('.') } if ignore
            return fs
        end

        def which(prog)
            return run("which #{prog}").strip
        end

        def dirs(ignore = true)
            return files(ignore, 'd')
        end

        def get_type(name)
            return :dir if run_status("[[ -d #{name} ]]") == 0
            return :file if run_status("[[ -f #{name} ]]") == 0
            raise "'#{name}' is neither file nor directory"
        end

        def expand_path(path)
            return run("echo #{path}").strip
        end

        def append_line(path, line)
            return run("echo '#{line}' >> #{path}")
        end

        def append_lines(path, lines)
            lines.each { |line|
                append_line(path, line)
            }
        end

        def contents(name)
            run("cat #{name}")
        end

        alias cat contents

        def hostname
            return run('hostname').strip
        end

        def touch(path)
            run("touch #{path}")
        end

        # BELOW ARE SPECIFIC METHODS FOR XPFLOW


        def packages
            list = run("dpkg -l")
            _unlines(list).map do |p|
                s, n, v = p.split
                { :status => s, :name => n, :version => v }
            end
        end

        def aptget(*args)
            raise 'Command not given' if args.length == 0
            cmd = args.first.to_sym
            args = args.map { |x| x.to_s }.join(' ')
            status = run_status("DEBIAN_FRONTEND=noninteractive apt-get -y #{args}")
            if cmd == :purge and status == 100
                return # ugly hack for the case when the package is not installed
            end
            raise StatusError.new('aptget', status, 'none') if status != 0
        end

        def distribute(path, dest, *nodes)
            # distributes a file to the given nodes
            nodes.flatten.each { |node|
                run("scp -o 'StrictHostKeyChecking no' #{path} #{node}:#{dest}")
            }
        end

        def glob(pattern)
            out, status = _run("ls -1 #{pattern}", {})
            return [] if status != 0
            return out.strip.lines.map { |x| x.strip }
        end

    end


    def self.bash(cmd = 'bash', debug = false, &block)
        if not block_given?
            sin, sout, _serr, _thr = Open3.popen3(cmd)
            return Bash.new(sin, sout, debug)
        end
        # run bash interpreter using this command
        result = nil
        Open3.popen3(cmd) do |cmdsin, cmdsout, _cmdserr, _cmdthr|
            dsl = Bash.new(cmdsin, cmdsout, debug)
            dsl.cd('~')   # go to the home dir
            result = dsl.parse(&block)
        end
        return result
    end

end; end

if __FILE__ == $0
    Cute::Bash.bash("ssh localhost bash") do
        cd '/tmp'
        puts files.inspect
        run 'rm /'
    end
end
