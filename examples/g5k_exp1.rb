require 'bundler'
Bundler.setup  # Use this when working in development mode.
require 'cute'

# This example tests two libraries for the execution of commands over several machines.
# These two  libraries use two different approaches: 1) SSH, 1) TakTuk.
# This example uses Grid'5000 but it can be used with any set of machines that can be accessed through SSH.

g5k = Cute::G5KAPI.new()
# We reuse a job if there is one available.
job = g5k.get_my_jobs("grenoble").empty? ? job = g5k.reserve(:nodes => 5, :site => 'grenoble', :walltime => '00:30:00') : g5k.get_my_jobs("grenoble").first

nodes_list = job["assigned_nodes"]

results = []

Net::SSH::Multi.start do |session|

  # session.via 'grenoble.g5k', 'cruizsanabria'
  nodes_list.each{ |node| session.use "cruizsanabria@#{node}" }
  session.exec 'hostname'
  session.exec 'ls -l'
  session.loop
  results = session.exec! 'df'
  session.exec 'uptime'
end

puts results

Cute::TakTuk.start(nodes_list,:login => "cruizsanabria" ) do |tak|

  tak.exec("df")
  results = tak.exec!("hostname")
  tak.exec 'ls -l'
  tak.loop()
  tak.exec("sleep 5")
  # tak.exec("tar xvf -")
  # tak.input(:file => "test_file.tar")

end


puts results
