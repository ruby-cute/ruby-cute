require 'restclient'
require 'yaml'
require 'json'
require 'ipaddress'
require 'uri'
require 'pry'

module Cute

  class G5KArray < Array

    def uids
      return self.map { |it| it['uid'] }
    end

    def __repr__
      return self.map { |it| it.__repr__ }.to_s
    end

    def rel_self
      return rel('self')
    end

    def rel(r)
      return self['links'].detect { |x| x['rel'] == r }['href']
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

    def resources
      return self['resources_by_type']
    end

    def rel(r)
      return self['links'].detect { |x| x['rel'] == r }['href']
    end

    def uid
      return self['uid']
    end

    def rel_self
      return rel('self')
    end

    def rel_parent
      return rel('parent')
    end

    def __repr__
      return self['uid'] unless self['uid'].nil?
      return Hash[self.map { |k, v| [k, v.__repr__ ] }].to_s
    end

    def refresh(g5k)
      return g5k.get_json(rel_self)
    end

    def self.parse(s)
      return JSON.parse(s, :object_class => G5KJson, :array_class => G5KArray)
    end


  end

  # Manages the low level operations for communicating with the REST API.
  class G5KRest

    attr_reader :user
    # Initializes a REST connection
    # @param uri [String] resource identifier which normally is the url of the Rest API
    # @param user [String] user if authentication is needed
    # @param pass [String] password if authentication is needed
    def initialize(uri,api_version,user,pass)
      @user = user
      @pass = pass
      @api_version = api_version.nil? ? "sid" : api_version
      if (user.nil? or pass.nil?)
        @endpoint = uri # Inside Grid'5000
      else
        user_escaped = CGI.escape(user)
        pass_escaped = CGI.escape(pass)
        @endpoint = "https://#{user_escaped}:#{pass_escaped}@#{uri.split("https://")[1]}"
      end

      machine =`uname -ov`.chop
      @user_agent = "ruby-cute/#{VERSION} (#{machine}) Ruby #{RUBY_VERSION}"
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

    # Creates a resource on the server
    # @param path [String] this complements the URI to address to a specific resource
    # @param json [Hash] contains the characteristics of the resources to be created.
    def post_json(path, json)
      r = resource(path).post(json.to_json,
                              :content_type => "application/json",
                              :accept => "application/json",
                              :user_agent => @user_agent)
      return G5KJson.parse(r)
    end

    # Delete a resource on the server
    # @param path [String] this complements the URI to address to a specific resource
    def delete_json(path)
      begin
        return resource(path).delete()
      rescue RestClient::InternalServerError => e
        raise
      end
    end

    # @return the parent link
    def follow_parent(obj)
      get_json(obj.rel_parent)
    end

    private

    # Test the connection and raises an error in case of a problem
    def test_connection
      begin
        return get_json("/#{@api_version}/")
        rescue RestClient::Unauthorized
          raise "Your Grid'5000 credentials are not recognized"
      end
    end

  end

  # Implements high level functions to get status information form Grid'5000 and
  # perform operations such as submitting jobs in the platform and deploying system images.
  class G5KAPI

    attr_accessor :logger
    # Initializes a REST connection for Grid'5000 API
    # @param params [Hash] contains initilization parameters.
    def initialize(params={})
      config = {}
      default_file = "#{ENV['HOME']}/.grid5000_api.yml"

      if params[:conf_file].nil? then
        params[:conf_file] =  default_file if File.exist?(default_file)
      end

      config = YAML.load(File.open(params[:conf_file],'r')) unless params[:conf_file].nil?
      @user = params[:user] || config["username"]
      @pass = params[:pass] || config["password"]
      @uri = params[:uri] || config["uri"]
      @api_version = params[:api_version] || config["version"] || "sid"
      @logger = nil

      begin
        @g5k_connection = G5KRest.new(@uri,@api_version,@user,@pass)
      rescue
        msg_create_file = ""
        if (not File.exist?(default_file)) && params[:conf_file].nil? then
          msg_create_file = "Please create the file: ~/.grid5000_api.yml and
                          put the necessary credentials or use the option
                          :conf_file to indicate another file for the credentials"
        end
        raise "Unable to authorize against the Grid'5000 API.
               #{msg_create_file}"

      end
    end

    # @return the rest point for perfoming low REST requests
    def rest
      @g5k_connection
    end

    # @return [String] Grid'5000 user
    def g5k_user
      return @user.nil? ? ENV['USER'] : @user
    end

    # @return [Array] all site identifiers
    def site_uids
      return sites.uids
    end

    # @return [Array] cluster identifiers
    def cluster_uids(site)
      return clusters(site).uids
    end

    # @return [Array] environment identifiers that can be used directly
    def environment_uids(site)
      # environments are returning by the api in the format squeeze-x64-big-1.8
      # it returns environments without the version
      return environments(site).uids.map{ |e| /(.*)-(.*)/.match(e)[1]}.uniq
    end

    # @return [Hash] all the status information of a given Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    def site_status(site)
      @g5k_connection.get_json(api_uri("sites/#{site}/status"))
    end

    # @return [Hash] the nodes state (e.g, free, busy, etc) that belong to a given Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    def nodes_status(site)
      nodes = {}
      site_status(site).nodes.each do |node|
        name = node[0]
        status = node[1]["soft"]
        nodes[name] = status
      end
      return nodes
    end

    # @return [Array] the description of all Grid'5000 sites
    def sites
      @g5k_connection.get_json(api_uri("sites")).items
    end

    # @return [Array] the description of the clusters that belong to a given Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    def clusters(site)
      @g5k_connection.get_json(api_uri("sites/#{site}/clusters")).items
    end

    # @return [Array] the description of all environments registered in a Grid'5000 site
    def environments(site)
      @g5k_connection.get_json(api_uri("sites/#{site}/environments")).items
    end
    # @return [Hash] all the jobs submitted in a given Grid'5000 site,
    #         if a uid is provided only the jobs owned by the user are shown.
    # @param site [String] a valid Grid'5000 site name
    # @param uid [String] user name in Grid'5000
    def get_jobs(site, uid = nil, state)
      filter = uid.nil? ? "" : "&user=#{uid}"
      jobs_running = @g5k_connection.get_json(api_uri("/sites/#{site}/jobs/?state=#{state}#{filter}")).items
      jobs_running.map{ |j| @g5k_connection.get_json(j.rel_self)}
    end

    # @return [Hash] the last 50 deployments performed in a Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    # @param uid [String] user name in Grid'5000
    def get_deployments(site, uid = nil)
      @g5k_connection.get_json(api_uri("sites/#{site}/deployments/?user=#{uid}")).items
    end

    # @return [Hash] information concerning a given job submitted in a Grid'5000 site
    # @param site [String] a valid Grid'5000 site name
    # @param jid [Fixnum] a valid job identifier
    def get_job(site, jid)
      @g5k_connection.get_json(api_uri("/sites/#{site}/jobs/#{jid}"))
    end

    # @return [Hash] switches information available in a given Grid'5000 site.
    # @param site [String] a valid Grid'5000 site name
    def get_switches(site)
      items = @g5k_connection.get_json("/sites/#{site}/network_equipments").items
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

    # @return [Hash] information of a specific switch available in a given Grid'5000 site.
    # @param site [String] a valid Grid'5000 site name
    # @param name [String] a valid switch name
    def get_switch(site, name)
      s = get_switches(site).detect { |x| x.uid == name }
      raise "Unknown switch '#{name}'" if s.nil?
      return s
    end

    # @return [Array] all my jobs submitted to a given site
    # @param site [String] a valid Grid'5000 site name
    def get_my_jobs(site, state="running")
      jobs = get_jobs(site, g5k_user,state)
      deployments = get_deployments(site, g5k_user)
      # filtering deployments
      jobs.map{ |j| j["deploy"] = deployments.select{ |d| d["created_at"] > j["started_at"]} }
      return jobs
    end

    # @return [Array] with the subnets reserved
    # @param site [String] a valid Grid'5000 site name
    def get_subnets(site)
      jobs = get_my_jobs(site)
      subnets = []
      jobs.each{ |j| subnets += @g5k_connection.get_json(j.rel_self).resources["subnets"] }
      subnets.map!{|s| IPAddress::IPv4.new s }
    end

    # releases all jobs on a site
    def release_all(site)
      Timeout.timeout(20) do
        jobs = get_my_jobs(site)
        break if jobs.empty?
        begin
          jobs.each { |j| release(j) }
        rescue RestClient::InternalServerError => e
          raise unless e.response.include?('already killed')
        end
      end
    end

    # Release a resource
    def release(r)
      begin
        return @g5k_connection.delete_json(r.rel_self)
      rescue RestClient::InternalServerError => e
        raise unless e.response.include?('already killed')
      end
    end

    # helper for making the reservations the easy way
    # @param opts [Hash] options compatible with OAR
    # reserve_nodes
    # :nodes => 1, :time => '01:00:00', :site => "nancy", :type => :normal
    # :name => "my reservation", :cluster=> "graphene", :subnets => [prefix_size, 2]
    # :env => "wheezy-x64-big", :vlan => :routed, :properties => "wattmeter='YES'"
    def reserve(opts)

      nodes = opts.fetch(:nodes, 1)
      time = opts.fetch(:time, '01:00:00')
      at = opts[:at]
      site = opts[:site]
      type = opts.fetch(:type, :normal)
      name = opts.fetch(:name, 'rubyCute job')
      command = opts[:cmd]
      async = opts[:async]
      ignore_dead = opts[:ignore_dead]
      cluster = opts[:cluster]
      switches = opts[:switches]
      cpus = opts[:cpus]
      cores = opts[:cores]
      subnets = opts[:subnets]
      properties = opts[:properties]
      type = :deploy unless opts[:env].nil?

      vlan_opts = {:routed => "kavlan",:global => "kavlan-global",:local => "kavlan-local"}
      vlan = nil
      unless opts[:vlan].nil?
        if vlan_opts.include?(opts[:vlan]) then
          vlan = vlan_opts.fetch(opts[:vlan])
        else
          raise 'Option for vlan not recognized'
        end
      end

      raise 'At least nodes, time and site must be given'  if [nodes, time, site].any? { |x| x.nil? }

      secs = time.to_secs
      time = time.to_time

      if nodes.is_a?(Array)
        all_nodes = nodes
        nodes = filter_dead_nodes(nodes) if ignore_dead
        removed_nodes = all_nodes - nodes
        info "Ignored nodes #{removed_nodes}." unless removed_nodes.empty?
        hosts = nodes.map { |n| "'#{n}'" }.sort.join(',')
        properties = "host in (#{hosts})"
        nodes = nodes.length
      end

      raise 'Nodes must be an integer.' unless nodes.is_a?(Integer)
      raise 'Type must be either :deploy or :normal' unless (type.respond_to?(:to_sym) && [ :normal, :deploy ].include?(type.to_sym))
      command = "sleep #{secs}" if command.nil?
      type = type.to_sym

      resources = ""
      resources = "/switch=#{switches}" unless switches.nil?
      resources = resources+"/nodes=#{nodes}"
      resources = resources+"/cpu=#{cpus}" unless cpus.nil?
      resources = resources+"/core=#{cores}" unless cores.nil?
      resources = resources+",walltime=#{time}"
      resources = "{cluster='#{cluster}'}" + resources unless cluster.nil?
      resources = "{type='#{vlan}'}/vlan=1+" + resources unless vlan.nil?
      resources = "slash_#{subnets[0]}=#{subnets[1]}+" + resources unless subnets.nil?

      payload = {
                 'resources' => resources,
                 'name' => name,
                 'command' => command
                }

      info "Reserving resources: #{resources} (type: #{type}) (in #{site})"

      payload['properties'] = properties unless properties.nil?

      if type == :deploy
        payload['types'] = [ 'deploy' ]
      else
        payload['types'] = [ 'allow_classic_ssh' ] if (cores.nil? && cpus.nil?)
      end

      unless at.nil?
        dt = parse_time(at)
        payload['reservation'] = dt
        info "Starting this reservation at #{dt}"
      end

      begin
        r = @g5k_connection.post_json(api_uri("sites/#{site}/jobs"),payload)  # This makes reference to the same class
      rescue => e
        info "Fail posting the json to the API"
        raise
      end

      job = @g5k_connection.get_json(r.rel_self)
      job = wait_for_job(job) if async != true
      #ref = {:job => job}
      # We deploy if necessary
      job["deploy"] = deploy(job,opts) if type == :deploy
      return job

    end

    # wait for the job to be in a running state
    # @param job [String] valid job identifier
    # @param wait_time [Fixnum] wait time before raising an exception, default 10h
    def wait_for_job(job,wait_time = 36000)

      jid = job
      info "Waiting for reservation #{jid}"
      Timeout.timeout(wait_time) do
        while true
          job = job.refresh(@g5k_connection)
          t = job['scheduled_at']
          if !t.nil?
            t = Time.at(t)
            secs = [ t - Time.now, 0 ].max.to_i
            info "Reservation #{jid} should be available at #{t} (#{secs} s)"
          end
          break if job['state'] == 'running'
          raise "Job is finishing." if job['state'] == 'finishing'
          Kernel.sleep(5)
        end
      end
      info "Reservation #{jid} ready"
      return job
    end

    # deploy an environment in a set of reserved nodes using Kadeploy
    # @param job [Hash] job structure
    # @param opts [Hash] options structure, it expects :env and optionally :public_key
    def deploy(job, opts = {})

      nodes = job['assigned_nodes']
      env = opts[:env]


      site = @g5k_connection.follow_parent(job).uid

      if opts[:public_key].nil? then
        public_key_path = File.expand_path("~/.ssh/id_rsa.pub")
        public_key_file = File.exist?(public_key_path) ? File.read(public_key_path) : ""
      else
        uri = URI.parse(opts[:public_key])
        case uri
        when URI::HTTP, URI::HTTPS
          public_key_file = uri.to_s
        else
        public_key_file = File.read(File.expand_path(opts[:public_key]))
        end
      end

      raise "Environment must be given" if env.nil?

      payload = {
                 'nodes' => nodes,
                 'environment' => env,
                 'key' => public_key_file,
                }

      if !job.resources["vlans"].nil?
        vlan = job.resources["vlans"].first
        payload['vlan'] = vlan
        info "Found VLAN with uid = #{vlan}"
      end

      info "Creating deployment"

      begin
        r = @g5k_connection.post_json(api_uri("sites/#{site}/deployments"), payload)
      rescue => e
        raise e
      end

      return r

    end

    def deploy_status(job)
      r = job["deploy"].is_a?(Array)? job["deploy"].first : job["deploy"]
      return nil if r.nil?
      r = r.refresh(@g5k_connection)
      r.delete "links"
      r
    end

    private
    # Handle the output of messages within the module
    # @param msg [String] message to show
    def info(msg)
      if @logger.nil? then
        t = Time.now
        s = t.strftime('%Y-%m-%d %H:%M:%S.%L')
        puts "#{s} => #{msg}"
      else
        @logger.info(msg)
      end
    end

    # @return a valid Grid'5000 resource
    # it avoids "//"
    def api_uri(path)
      path = path[1..-1] if path.start_with?('/')
      return "#{@api_version}/#{path}"
    end

  end

end
