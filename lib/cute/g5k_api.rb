require 'restclient'
require 'yaml'
require 'json'

module Cute

  class G5KArray < Array

    def uids
      return self.map { |it| it['uid'] }
    end

    def __repr__
      return self.map { |it| it.__repr__ }.to_s
    end

  end

  class G5KJson < Hash

    def items
      return self['items']
    end

    def nodes
      return self['nodes']
    end

    def __repr__
      return self['uid'] unless self['uid'].nil?
      return Hash[self.map { |k, v| [k, v.__repr__ ] }].to_s
    end

    def self.parse(s)
      return JSON.parse(s, :object_class => G5KJson, :array_class => G5KArray)
    end


  end

  class G5KRest

    # Basic Grid5000 Rest Interface
    attr_reader :user, :api

    def initialize(uri,user=nil,pass=nil)
      @user = user
      @pass = pass
      if (user.nil? or pass.nil?)
        @endpoint = uri # Inside Grid'5000
      else
        user_escaped = CGI.escape(user)
        pass_escaped = CGI.escape(pass)
        @endpoint = "https://#{user_escaped}:#{pass_escaped}@#{uri.split("https://")[1]}"
      end
      @api = RestClient::Resource.new(@endpoint, :timeout => 15)
      test_connection
    end

    def resource(path)
      path = path[1..-1] if path.start_with?('/')
      return @api[path]
    end

    def get_json(path)
      maxfails = 3
      fails = 0
      while true
        begin
          r = resource(path).get()
          return G5KJson.parse(r)
        rescue RestClient::RequestTimeout
          fails += 1
          raise if fails > maxfails
          Kernel.sleep(1.0)
        end
      end
    end

    private

    def test_connection
      begin
        return get_json("")
        rescue RestClient::Unauthorized
          raise "Your Grid'5000 credentials are not recognized"
      end
    end

  end

  class G5KUser

    def initialize(uri,user=nil,pass=nil)
      @g5k_connection = G5KRest.new(uri,user,pass)
    end

    def site_uids
      return sites.uids
    end

    def cluster_uids(site)
      return clusters(site).uids
    end

    def site_status(site)
      @g5k_connection.get_json("sites/#{site}/status")
    end

    def get_nodes_status(site)
      nodes = {}
      site_status(site).nodes.each do |node|
        name = node[0]
        status = node[1]["soft"]
        nodes[name] = status
      end
      return nodes
    end

    def sites
      @g5k_connection.get_json("sites").items
    end

    def clusters(site)
      @g5k_connection.get_json("sites/#{site}/clusters").items
    end

    def get_jobs(site, uid = nil)
      filter = uid.nil? ? "" : "&user_uid=#{uid}"
      @g5k_connection.get_json("sites/#{site}/jobs/?state=running#{filter}")
    end

    def get_job(site, jid)
      @g5k_connection.get_json("sites/#{site}/jobs/#{jid}")
    end

    def get_switches(site)
      items = @g5k_connection.get_json("sites/#{site}/network_equipments").items
      items = items.select { |x| x['kind'] == 'switch' }
      # extract nodes connected to those switches
      items.each { |switch|
        conns = switch['linecards'].detect { |c| c['kind'] == 'node' }
        next if conns.nil?  # IB switches for example
        nodes = conns['ports'] \
          .select { |x| x != {} } \
          .map { |x| x['uid'] } \
          .map { |x| "#{x}.#{site}.grid5000.fr"}
        switch['nodes'] = nodes
      }
      return items.select { |it| it.key?('nodes') }
    end

    def get_switch(site, name)
      s = get_switches(site).detect { |x| x.uid == name }
      raise "Unknown switch '#{name}'" if s.nil?
      return s
    end

  end

end
