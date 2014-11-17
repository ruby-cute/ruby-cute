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

  # Provides an abstraction for handling G5K responses
  # @see https://api.grid5000.fr/doc/3.0/reference/grid5000-media-types.html
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

  # Manages the low level operations for communicating with the REST API.
  class G5KRest

    attr_reader :user, :api

    # Initializes a REST connection
    # @param uri [String] resource identifier which normally is the url of the Rest API
    # @param user [String] user if authentication is needed
    # @param pass [String] password if authentication is needed
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

    # Returns a resource object
    # @param path [String] this complements the URI to address to a specific resource
    def resource(path)
      path = path[1..-1] if path.start_with?('/')
      return @api[path]
    end

    # Returns the HTTP response as a Ruby Hash
    # @param path [String] this complements the URI to address to a specific resource
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

    # Test the connection and raises an error in case of a problem
    def test_connection
      begin
        return get_json("")
        rescue RestClient::Unauthorized
          raise "Your Grid'5000 credentials are not recognized"
      end
    end

  end

  # Implements high level functions to get status information form Grid'5000 and
  # performs operations such as submitting jobs in the platform and deploying system images.
  class G5KUser

    # Initializes a REST connection for Grid'5000 API
    # @param uri [String] resource identifier which normally is the url of the Rest API
    # @param user [String] user if authentication is needed
    # @param pass [String] password if authentication is needed
    def initialize(uri,user=nil,pass=nil)
      @g5k_connection = G5KRest.new(uri,user,pass)
    end

    # Returns the site identifiers
    def site_uids
      return sites.uids
    end

    # Returns the cluster identifiers
    def cluster_uids(site)
      return clusters(site).uids
    end

    # @return [Hash] all the status information of a given Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    def site_status(site)
      @g5k_connection.get_json("sites/#{site}/status")
    end

    # @return [Hash] the nodes state (e.g, free, busy, etc) that belong to a given Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    def get_nodes_status(site)
      nodes = {}
      site_status(site).nodes.each do |node|
        name = node[0]
        status = node[1]["soft"]
        nodes[name] = status
      end
      return nodes
    end

    # @return [Hash] the description of all Grid'5000 sites
    def sites
      @g5k_connection.get_json("sites").items
    end

    # @return [Hash] the description of the clusters that belong to a given Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    def clusters(site)
      @g5k_connection.get_json("sites/#{site}/clusters").items
    end

    # Returns all the jobs submitted in a given Grid'5000 site,
    # if a uid is provided only the jobs owned by the user are shown.
    # @param site [String] a valid Grid'5000 site name
    # @param uid [String] user name in Grid'5000
    def get_jobs(site, uid = nil)
      filter = uid.nil? ? "" : "&user_uid=#{uid}"
      @g5k_connection.get_json("sites/#{site}/jobs/?state=running#{filter}")
    end

    # @return [Hash] information concerning a given job submitted in a Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    # @param jid [Fixnum] a valid job identifier
    def get_job(site, jid)
      @g5k_connection.get_json("sites/#{site}/jobs/#{jid}")
    end

    # @return [Hash] switches information available in a given Grid'5000 site.
    # @param site [String] a valid Grid'5000 site name
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

    # Return information of a specific switch available in a given Grid'5000 site.
    # @param site [String] a valid Grid'5000 site name
    # @param name [String] a valid switch name
    def get_switch(site, name)
      s = get_switches(site).detect { |x| x.uid == name }
      raise "Unknown switch '#{name}'" if s.nil?
      return s
    end

  end

end
