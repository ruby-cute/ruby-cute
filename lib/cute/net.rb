module Cute
  module Network
    require 'socket'

    def Network::port_open?(ip, port)
      begin
        s = TCPSocket.new(ip, port)
        s.close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
        return false
      end
    end

    def Network::wait_open_port(host, port, timeout = 120)
      now = -> { return Time.now.to_f }
      bound = now.call + timeout
      while now.call < bound do
        t = now.call
        return true if port_open?(host, port)
        dt = now.call - t
        sleep(0.5 - dt) if dt < 0.5
      end
      return false
    end
  end
end
