def do_backbone
  default_remotes = %w{lille sophia}.sort
  default_sites = $g5k.site_uids.sort
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner =  "usage: grd backbone"
    opts.separator "  List status of backbone network usage for each site"

    opts.on("-v", "--verbose", "Enable verbose output") { options[:verbose] = true }
    opts.on("-j", "--json", "Enable json output") { options[:json] = true }

    opts.on("-rNAME", "--remote=NAME", "Specify a custom remote to test from (default: #{default_remotes.join(' ')})") do |name|
      options[:custom_remotes] ||= []
      options[:custom_remotes] << name
    end

    opts.on("-sNAME", "--site=NAME", "Specify a site to check (default: #{default_sites.join(' ')})") do |name|
      options[:custom_sites] ||= []
      options[:custom_sites] << name
    end


    # Define an option to display help
    opts.on("-h", "--help", "Display help information") do
      puts opts
      exit
    end
  end

  # Parse the arguments
  parser.parse!

  sites = options[:custom_sites] ? options[:custom_sites] : default_sites
  remotes = options[:custom_remotes] ? options[:custom_remotes] : default_remotes

  results = {}
  m = Mutex.new
  remotes.peach do |remote|
    sites.peach(100) do |site|
      fnode = "frontend.#{remote}.grid5000.fr"
      rgw = "gw.#{site}.grid5000.fr"
      cmd = "mtr -j -c 1 -G 1 #{rgw}"
      begin
        next if remote == site
        if g5k_internal?
          ssh = Net::SSH.start(fnode, $login)
        else
          gw = Net::SSH::Gateway.new('access.grid5000.fr', $login)
          ssh = gw.ssh(fnode, $login)
        end
        o = ssh.exec3!(cmd, {:no_log => true, :no_output => true} )
        m.synchronize do
          results[site] ||= {'remotes' => {} }
          results[site]['remotes'][remote] = { 'raw' => o }
        end
        ssh.close
        ssh.shutdown!
        if not g5k_internal?
          gw.shutdown!
        end
      rescue
        raise "Failed to run #{cmd} on #{fnode}: #{$!.message}"
      end
    end
  end
  # analyze results
  results.each_pair do |site, res|
    res['remotes'].each_pair do |rem, d|
      if d['raw'][:exit_code] != 0
        d['status'] = :error
      else
        mtr = JSON::load(d['raw'][:stdout])
        if mtr['report']['hubs'].length == 2 and mtr['report']['hubs'].last['host'] == "gw.#{site}.grid5000.fr"
          d['status'] = :backbone
        elsif mtr['report']['hubs'].any? { |e| e['host'] == 'vpn.grid5000.fr' } and mtr['report']['hubs'].last['host'] == "gw.#{site}.grid5000.fr"
          d['status'] = :backup
        else
          if options[:verbose]
            puts "Result for #{site} from #{rem} is unknown. Raw result:"
            pp mtr
          end
          d['status'] = :unknown
        end
      end
    end
  end
  results.each_pair do |site, res|
    st = res['remotes'].values.map { |e| e['status'] }
    if st.uniq.length == 1
      res['status'] = st.uniq.first
    else
      if options[:verbose]
        puts "Result for #{site} is unclear. Raw results:"
        pp res['remotes']
      end
      res['status'] = :unclear
    end
  end
  if options[:json]
    results = results.to_a.map { |e| e[1]['site'] = e[0] ; e[1] }
    if not options[:verbose]
      results.each do |v|
        v.delete('remotes')
      end
    end
    puts puts JSON.pretty_generate(results)
  else
    [ :backbone, :backup, :unknown, :error, :unclear ].each do |i|
      sites = results.to_a.select { |j| j[1]['status'] ==  i }
      if sites.length > 0
        puts "#{i.to_s.capitalize}: #{sites.map(&:first).sort.join(' ')}"
      end
    end
  end
end
