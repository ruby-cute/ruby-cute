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
      def now()
        return Time.now.to_f
      end
      bound = now() + timeout
      while now() < bound do
        t = now()
        return true if port_open?(host, port)
        dt = now() - t
        sleep(0.5 - dt) if dt < 0.5
      end
      return false
    end
  end
end
