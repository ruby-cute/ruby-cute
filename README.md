# Ruby-Cute

Ruby-Cute is a set of *Commonly Used Tools for Experiments*, or *Critically
Useful Tools for Experiments*, depending on who you ask. It is a library
aggregating various Ruby snippets useful in the context of (but not limited to)
development of experiment software on distributed systems testbeds such as
Grid'5000.

Ruby-Cute also includes the **grd** command line utility, that provides a
modern interface to typical Grid'5000 workflows. As an example, `grd bootstrap -s
ly -l nodes=3 -w 0:10 -e debian11-x64-min -f setup-script -c` will reserve 3
nodes on the *lyon* site, provision the *debian11-x64-min* environment, run
*setup-script* on the first node, and then connect interactively using SSH.

For more information about how to use **grd**, run `grd --help` and `grd
bootstrap --help` on any frontend. **grd** can also work from your own computer
(outside Grid'5000).

## Installation

To install latest release from [RubyGems](https://rubygems.org/gems/ruby-cute):

```bash
$ gem install --user-install ruby-cute
```
From sources:

```bash
$ git clone https://github.com/ruby-cute/ruby-cute
$ cd ruby-cute
$ gem build ruby-cute.gemspec
$ gem install --user-install ruby-cute-*.gem
```

Then, type the following to have ruby-cute in your path (this is only necessary
if you want to use the executables included in ruby-cute, such as grd).

```bash
$ export PATH=$PATH:$(ruby -e 'puts "#{Gem.user_dir}/bin"')
```
If you want to use Ruby-Cute outside Grid'5000 you need to create a configuration file with your credentials.
By default you need to create a file called *.grid5000_api.yml* located in your home directory:

```bash

$ cat > ~/.grid5000_api.yml << EOF
uri: https://api.grid5000.fr/
username: user
password: **********
EOF

$ chmod og-r ~/.grid5000_api.yml

```

For more details have a look at [G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API).

## Overview

Ruby-Cute is structured in different modules that allows you to:

- communicate with Grid'5000 through the G5K Module. For more details please refer to
  [G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API).

- execute commands in several remote machines in parallel. Two modules are available for that:

    - [Net::SSH::Multi](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Net/SSH/Multi) that uses the SSH protocol.
    - [TakTuk](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/TakTuk)
      which is a wrapper of [taktuk](http://taktuk.gforge.inria.fr) parallel command executor.

An example of use of Ruby-Cute in a real use case is available in
[Virtualization on Grid'5000](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/file/examples/g5k_exp_virt.rb)

## Using pry -- an interactive ruby shell

Sometimes it may be useful to work in interactive mode. For this we can use an interactive ruby shell such as irb that is shipped by default with
Ruby, however, we highly recommend to use [pry](http://pryrepl.org/), it features syntax highlighting, method auto completion and command shell integration.
For installing pry type the following:

```bash
$ gem install pry
```

or, for installing in the user home directory:

```bash
$ gem install --user-install pry
```

When Ruby-Cute is installed, it provides a wrapper for an interactive shell that will
automatically load the necessary libraries. The following will get a *pry* prompt (if installed).

```bash
$ cute
[1] pry(main)>
```

The variable *$g5k* is available which can be used to access the Grid'5000 API through the
[G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API). For example,
let's request the name of the sites available in Grid'5000.
(Before starting be sure to set up a configuration file for the module, please refer to
[G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API))

```bash
[2] pry(main)> $g5k.site_uids()
 => ["grenoble", "lille", "luxembourg", "lyon", "nancy", "nantes", "reims", "rennes", "sophia", "toulouse"]
```

We can get the status of nodes in a given site by using:

```bash
[8] pry(main)> $g5k.nodes_status("lyon")
 => {"taurus-2.lyon.grid5000.fr"=>"besteffort", "taurus-16.lyon.grid5000.fr"=>"besteffort", "taurus-15.lyon.grid5000.fr"=>"besteffort", ...}
```

Within this shell you have preloaded [G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API),
[Taktuk](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/TakTuk) and
[Net::SSH::Multi](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Net/SSH/Multi),
you can go directly to their respective documentation to know how to take advantage of them.

### Examples

The following examples show how to use the [G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API) in an experiment.

#### Example 1: automatic experiment bootstrap

This example (also available as
[examples/xp-bootstrap](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/file/examples/xp-bootstrap))
is a simple script automating the initial bootstrap of an experiment (deployment, software setup).

```ruby
#!/usr/bin/ruby -w

# This script, to be executed on a frontend, automates the initial setup
# of an experiment, and then sleeps to let the user take over.
# The same script, run with --reserve, will handle resources reservation

# To make this work:
# - connect to a frontend
# - install ruby-cute: gem install --user-install ruby-cute
# - get this script, make it executable (chmod a+rx xp-bootstrap)
# - run it: ./xp-bootstrap --reserve

gem 'ruby-cute', ">=0.6"
require 'cute'
require 'pp'

g5k = Cute::G5K::API.new
G5K_SITE = `hostname --fqdn`.split('.')[-3] # get the site name from the `hostname` command
G5K_ENV = 'jessie-x64-base' # environment to deploy
NODES = 2
WALLTIME = '0:30'

# When the script is run with --reserve, use Ruby-Cute to reserve resources and run the script again inside the reservation, when it starts
if ARGV[0] == '--reserve'
  # reserve two nodes for 30 mins
  job = g5k.reserve(:site => G5K_SITE, :nodes => NODES, :walltime => WALLTIME, :type => :deploy, :wait => false,
                    :name => 'xp-bootstrap',
                    :cmd => File::realpath(__FILE__)
                   )
  puts "Job #{job['uid']} created. Monitor its status with e.g.: oarstat -fj #{job['uid']}"
  exit(0)
end

###########################################################################
#### What follows is what gets executed inside the resources reservation

# for better output, redirect stderr to stdout, make stdout a synchronized output stream
STDERR.reopen(STDOUT)
STDOUT.sync = true

jobid = ENV['OAR_JOB_ID']
raise "OAR_JOB_ID not set. Are you running inside a OAR reservation? Maybe you should use #{__FILE__} --reserve?" if not jobid

# get job details
job = g5k.get_job(G5K_SITE, jobid)
nodes = job['assigned_nodes']
puts "Running on: #{nodes.join(' ')}"

# deploying all nodes, waiting for the end of deployment
g5k.deploy(job,  :env => G5K_ENV, :wait => true)

raise "Deployment ended with error" if ((job['deploy'].last['status'] == 'error') or (not job['deploy'].last['result'].to_a.all? { |e| e[1]['state'] == 'OK' }))

cmd = 'apt-get update && apt-get -y install nuttcp'
puts "Running command: #{cmd}"
# Run a command on each node and analyze result
ssh = Net::SSH::Multi::Session::new
nodes.each { |n| ssh.use "root@#{n}" }
r = ssh.exec!(cmd)
raise "Command failed on at least one node\n#{r}" if not r.to_a.all? { |e| e[1][:status] == 0 }

# Sleep for a very long time to avoid reservation termination 
puts "Experiment preparation finished."
puts "Nodes: #{nodes.join(' ')}"
sleep 86400*365
```

#### Example 2: running MPI

This example implements the experiment described in
[MPI on Grid5000](https://www.grid5000.fr/mediawiki/index.php/Run_MPI_On_Grid%275000#Setting_up_and_starting_Open_MPI_to_use_high_performance_interconnect).

```ruby
require 'cute'
require 'net/scp'

g5k = Cute::G5K::API.new()
# We reuse a job if there is one available.
G5K_SITE = "nancy" # the chosen site has to have Infiniband 20G (e.g nancy, grenoble)
if g5k.get_my_jobs(G5K_SITE).empty?
   job = g5k.reserve(:site => G5K_SITE, :resources => "{ib20g='YES'}/nodes=2/core=1",:walltime => '00:30:00', :keys => "~/my_ssh_jobkey" )
else
   job = g5k.get_my_jobs(G5K_SITE).first
end

nodes = job["assigned_nodes"]

grid5000_opt = {:user => "oar", :keys => ["~/my_ssh_jobkey"], :port => 6667 }

machine_file = Tempfile.open('machine_file')

nodes.each{ |node| machine_file.puts node }

machine_file.close

netpipe ="http://pkgs.fedoraproject.org/repo/pkgs/NetPIPE/NetPIPE-3.7.1.tar.gz/5f720541387be065afdefc81d438b712/NetPIPE-3.7.1.tar.gz"

# We use the first node reserved.
Net::SCP.start(nodes.first, "oar", grid5000_opt) do |scp|
   scp.upload! machine_file.path, "/tmp/machine_file"
end

Net::SSH.start(nodes.first, "oar", grid5000_opt) do |ssh|
   ssh.exec!("mkdir -p netpipe_exp")
   ssh.exec!("export http_proxy=\"http://proxy:3128\"; wget -O ~/netpipe_exp/NetPIPE.tar.gz #{netpipe}")
   ssh.exec!("cd netpipe_exp && tar -zvxf NetPIPE.tar.gz")
   ssh.exec!("cd netpipe_exp/NetPIPE-3.7.1 && make mpi")
   ssh.exec("mpirun --mca plm_rsh_agent \"oarsh\" -machinefile /tmp/machine_file ~/netpipe_exp/NetPIPE-3.7.1/NPmpi")
end

g5k.release(job) # Frees resources.
```

## Contact information

Ruby-Cute is maintained by the Madynes team at LORIA/Inria Nancy - Grand Est, and specifically by:

* Lucas Nussbaum <lucas.nussbaum@loria.fr>

Past contributors include:

* Sébastien Badia <sebastien.badia@inria.fr>
* Tomasz Buchert <tomasz.buchert@inria.fr>
* Emmanuel Jeanvoine <emmanuel.jeanvoine@inria.fr>
* Cristian Ruiz <cristian.ruiz@inria.fr>
* Luc Sarzyniec <luc.sarzyniec@inria.fr>

Questions/comments should be directed to Lucas Nussbaum.
