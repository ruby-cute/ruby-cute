require 'cute'

# This example tests two libraries for the execution of commands over several machines.
# These two  libraries use two different approaches: 1) SSH, 1) TakTuk.
# This example uses Grid'5000 but it can be used with any set of machines that can be accessed through SSH.

g5k = Cute::G5K::API.new()
# We reuse a job if there is one available.
if g5k.get_my_jobs("grenoble").empty? then
  job = g5k.reserve(:nodes => 5, :site => 'grenoble', :walltime => '00:30:00')
else
  job =g5k.get_my_jobs("grenoble").first
end

nodes = job["assigned_nodes"]

results = {}

# please change user by your Grid'5000 user.
Net::SSH::Multi.start do |session|

  nodes.each{ |node| session.use "user@#{node}" }
  session.exec 'hostname'
  session.loop
  results = session.exec! 'df'
  session.exec 'uptime'
end

puts results

Cute::TakTuk.start(nodes,:user => "user" ) do |tak|

  results = tak.exec!("hostname")
  tak.loop()
  tak.exec("df")
  tak.exec("uname -r")

end


puts results
