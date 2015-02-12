# Ruby-Cute

Ruby-Cute is a set of *Commonly Used Tools for Experiments*, or *Critically
Useful Tools for Experiments*, depending on who you ask. It is a library
aggregating various Ruby snippets useful in the context of (but not limited to)
development of experiment software on distributed systems testbeds such as
Grid'5000.

## Installation

From sources:

    $ git clone https://gforge.inria.fr/git/ruby-cute/ruby-cute.git
    $ cd ruby-cute
    $ gem build ruby-cute.gemspec
    $ gem install ruby-cute-*.gem

In Grid'5000 the installation procedure goes as follows:

    $ gem install --user-install ruby-cute-*.gem

Then, type the following for having ruby cute in your path (this is only necessary if you want to use interactive mode).

    $ export PATH=$PATH:$(ruby -e 'puts "#{Gem.user_dir}/bin"')

## G5K Module

This module helps you to access Grid'5000 REST API.
Thus, the most common actions such as reservation of nodes and deployment can be easily scripted.
To simplify the use of the module, it is better to create a file with the following information:

    $ cat > ~/.grid5000_api.yml << EOF
    $ uri: https://api.grid5000.fr/
    $ username: user
    $ password: **********
    $ version: sid
    $ EOF

The *username* and *password* are not necessary if you are using the module from inside Grid'5000.

You can specify another file using the option :conf_file, for example:

    g5k = Cute::G5K::API.new({:conf_file =>"config file path"})

Or you can specify other parameter to use:

    g5k = Cute::G5K::API.new({:uri => "https://api.grid5000.fr"})

## Examples

### Reserving a node in a given site.
The following script will reserve a node in Nancy for 10 minutes.

    require 'cute'

    g5k = Cute::G5K::API.new()
    job = g5k.reserve(:nodes => 1, :site => 'nancy', :walltime => '00:10:00')

### Deploying an environment.

This script will reserve and deploy the *wheezy-x64-base* environment.
Your public ssh key located in *~/.ssh* will be copied by default to the deployed machines,
you can specify another path for your keys with the option *:keys*.

    require 'cute'

    g5k = Cute::G5K::API.new()

    job = g5k.reserve(:nodes => 1, :site => 'grenoble',
                            :walltime => '00:40:00',
                            :env => 'wheezy-x64-base')

The previous examples can be executed using the ruby interpreter.

    $ ruby example.rb

For more details and examples please refer to {Cute::G5K::API G5K Module}.

### Using pry -- an interactive ruby shell

Sometimes it may be useful to work in interactive mode. For this we can use an interactive ruby shell such as irb that is shipped by default with
Ruby, however, we highly recommend to use {http://pryrepl.org/ pry}, it features syntax highlighting, method auto completion and command shell integration.
For installing pry type the following:

    $ gem install pry

or, for installing in the user home directory:

    $ gem install --user-install pry

When Ruby-Cute is installed, it provides a wrapper for an interactive shell that will
automatically load the necessary libraries. The following will get a pry prompt (if installed).

    $ cute
    [1] pry(main)>

The variable *$g5k* is available which can be used to access the Grid'5000 API. For example,
let's request the name of the sites available in Grid'5000.

    [2] pry(main)> $g5k.site_uids()
    => ["grenoble", "lille", "luxembourg", "lyon", "nancy", "nantes", "reims", "rennes", "sophia", "toulouse"]

We can consult the name of the cluster available in a specific site.

    [4] pry(main)> $g5k.cluster_uids("grenoble")
    => ["adonis", "edel", "genepi"]

As well as the deployable environments:

    [6] pry(main)> $g5k.environment_uids("grenoble")
    => ["squeeze-x64-base", "squeeze-x64-big", "squeeze-x64-nfs", "wheezy-x64-base", "wheezy-x64-big", "wheezy-x64-min", "wheezy-x64-nfs", "wheezy-x64-xen"]

Additionally, you can use all methods already presented and the ones presented in {Cute::G5K::API G5K Module} which allow to
consult the jobs that you have submitted, to deploy an environment on them, monitoring reservations and deployments, etc.

### Interacting with resources

Ruby Cute provides modules for executing commands in many remote nodes. Two modules are available:

   - {Net::SSH::Multi Net::SSH::Multi} that uses the SSH protocol
   - {Cute::TakTuk Taktuk} which is a wrapper of {http://taktuk.gforge.inria.fr/  taktuk} parallel command executor.

An example of their utilization in a real use case is available in {file:docs/g5k_exp_virt.md  Virtualization on Grid'5000}.

### Experiment example

The following example shows how to use the {Cute::G5K::API G5K Module} in an experiment.
This example implements the experiment described in
{https://www.grid5000.fr/mediawiki/index.php/Run_MPI_On_Grid%275000#Setting_up_and_starting_Open_MPI_to_use_high_performance_interconnect MPI on Grid5000}.
If you want to adapt it to another site, you have to verify that the properties are valid to the site in question.
For example, some sites do not have the filed 'ib20g' to YES, they probabily have instead 'ib10g'.

    require 'cute'
    require 'net/scp'

    g5k = Cute::G5K::API.new()
    # We reuse a job if there is one available.
    G5K_SITE = "nancy"
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


## Contact information

Ruby-Cute is maintained by the Algorille team at LORIA/Inria Nancy - Grand Est, and specifically by:

* Cristian Ruiz <cristian.ruiz@inria.fr>
* Emmanuel Jeanvoine <emmanuel.jeanvoine@inria.fr>
* Lucas Nussbaum <lucas.nussbaum@loria.fr>

Past contributors include:

* Sébastien Badia <sebastien.badia@inria.fr>
* Tomasz Buchert <tomasz.buchert@inria.fr>
* Luc Sarzyniec <luc.sarzyniec@inria.fr>

Questions/comments should be directed to Lucas Nussbaum and Emmanuel Jeanvoine.
