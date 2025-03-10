require 'net/ssh'

class Net::SSH::Connection::Session
  # Monkey patch that adds the exec3! method.
  # It executes a command, waits for the result, and returns the output as a hash indexed with :stdout, :stderr, :exit_code, :exit_signal.
  # Several options are available: :no_log (don't display anything), :no_output (don't show command output), :merge_outputs (merge stdout and stderr),
  # :ignore_error (don't raise an exception if the command execution fails).
  #
  # @return [Hash] result Hash stdout, stderr, exit_code, exit_signal of executed command
  def exec3!(command, o = {})
    puts "SSH exec3 on #{host}: #{command}" unless o[:no_log]
    res = {}
    open_channel do |channel|
      channel.exec(command) do |_ch, success|
        unless success
          abort "FAILED: couldn't execute command (ssh.channel.exec)"
        end
        channel.collect_outputs(res, o)
      end
    end
    self.loop
    if res[:exit_code] != 0 and not o[:ignore_error]
      puts "SSH exec3 failed: #{command}"
      pp res
      raise "SSH exec3 failed: #{command}"
    end
    res
  end
end

class Net::SSH::Connection::Channel
  # This mixin collects the channel's stdout, stderr, exit_code and exit_signal into a hash
  def collect_outputs(res, o = {})
    ts = Time::now
    res[:stdout] = ""
    res[:stderr] = ""
    res[:exit_code] = nil
    res[:exit_signal] = nil

    on_data do |_ch,data|
      print data unless o[:no_output]
      res[:stdout]+=data
    end

    on_extended_data do |_ch,_type,data|
      print data unless o[:no_output]
      if o[:merge_outputs]
        res[:stdout]+=data
      else
        res[:stderr]+=data
      end
    end

    on_request("exit-status") do |_ch,data|
      res[:exit_code] = data.read_long
      d = sprintf("%.1f", Time::now - ts)
      puts "EXITCODE: #{res[:exit_code]} (duration: #{d}s)" unless o[:no_log]
    end

    on_request("exit-signal") do |_ch, data|
      res[:exit_signal] = data.read_long
      d = sprintf("%.1f", Time::now - ts)
      puts "EXITSIGNAL: #{res[:exit_signal]} (duration: #{d}s)" unless o[:no_log]
    end
  end
end

