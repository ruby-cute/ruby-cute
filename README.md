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

*username* and *password* are not necessary if you are using the module from inside Grid'5000.

You can specify another file using the option :conf_file, for example:

    g5k = Cute::G5KAPI.new({:conf_file =>"config file path"})

Or you can specify other parameter to use:

    g5k = Cute::G5KAPI.new({:uri => "https://api.grid5000.fr"})

## Examples

### Reserving a node in a given site.
The following script will reserve a node in Nancy for 10 minutes.

    require 'cute'

    g5k = Cute::G5KAPI.new()
    job = g5k.reserve(:nodes => 1, :site => 'nancy', :walltime => '00:10:00')

Other examples with properties:

    job = g5k.reserve(:site => 'lyon', :nodes => 2, :properties => "wattmeter='YES'")

    job = g5k.reserve(:site => 'nancy', :nodes => 1, :properties => "switch='sgraphene1'")

    job = g5k.reserve(:site => 'nancy', :nodes => 1, :properties => "cputype='Intel Xeon E5-2650'")

All non-deploy reservations are submitted by default with the OAR option "-allow_classic_ssh"
which does not take advantage of the CPU/core management level.
Therefore, in order to take advantage of this capability, SSH keys have to be specified at the moment of reserving resources.
This has to be used whenever we perform a reservation with cpu and core hierarchy.
Users are encouraged to create a pair of SSH keys for managing jobs, for instance the following command can be used:

    ssh-keygen -N "" -t rsa -f ~/my_ssh_jobkey

The reserved resources can be accessed using "oarsh" or by configuring the SSH connection as shown in {https://www.grid5000.fr/mediawiki/index.php/OAR2 OAR2}.
You have to specify different keys per reservation if you want several jobs running at the same time in the same site.
Examples using the OAR hierarchy:

    job = g5k.reserve(:site => "grenoble", :switches => 3, :nodes => 1, :cpus => 1, :cores => 1, :keys => "~/my_ssh_jobkey")

The previous reservation can be done as well using the OAR syntax:

    job = g5k.reserve(:site => "grenoble", :resources => "/switch=3/nodes=1/cpu=1/core=1", :keys => "~/my_ssh_jobkey")

This syntax allow to express more complex reservations. For example, combining OAR hierarchy with properties:

    job = g5k.reserve(:site => "grenoble", :resources => "{ib10g='YES' and memnode=24160}/cluster=1/nodes=2/core=1", :keys => "~/my_ssh_jobkey")

If we want 2 nodes with the following constraints:
1) nodes on 2 different clusters of the same site, 2) nodes with virtualization capability enabled
3) 1 /22 subnet. The reservation will be like:

    job = g5k.reserve(:site => "rennes", :resources => "/slash_22=1+{virtual!='none'}/cluster=2/nodes=1")

Another reservation for two clusters:

    job = g5k.reserve(:site => "nancy", :resources => "{cluster='graphene'}/nodes=2+{cluster='griffon'}/nodes=3")

### Deploying an environment.

This script will reserve and deploy the *wheezy-x64-base* environment.
Your public ssh key located in *~/.ssh* will be copied by default to the deployed machines,
you can specify another path for your generated keys with the option *:keys*, as explained before.

    require 'cute'

    g5k = Cute::G5KAPI.new()

    job = g5k.reserve(:nodes => 1, :site => 'grenoble',
                            :walltime => '00:40:00',
                            :env => 'wheezy-x64-base')


### Complex reservation

The method {Cute::G5KAPI#reserve reserve} support several parameters to perform more complex reservations.
The script below reserves 2 nodes in the cluster *chirloute* located in Lille for 1 hour as well as 2 /22 subnets.
2048 IP addresses will be available that can be used, for example, in virtual machines.

    require 'cute'

    g5k = Cute::G5KAPI.new()

    job = g5k.reserve(:site => 'lille', :cluster => 'chirloute', :nodes => 2,
                            :time => '01:00:00', :env => 'wheezy-x64-xen',
                            :keys => "~/my_ssh_jobkey",
                            :subnets => [22,2])

*VLANS* are supported by adding the parameter *:vlan => type* where type can be: *:routed*, *:local*, *:global*.
If walltime is not specified, 1 hour walltime will be assigned to the reservation.

    job = g5k.reserve(:nodes => 1, :site => 'nancy',
                            :vlan => :local, :env => 'wheezy-x64-xen')


In order to deploy your own environment,
you have to put the tar file that contains the operating system you want to deploy and
the environment description file, under the public directory of a given site.
Then, you simply write:

    job = g5k.reserve(:site => "lille", :nodes => 1,
                            :env => 'https://public.lyon.grid5000.fr/~user/debian_custom_img.yaml')


### Experiment example

The following example shows how to use the {Cute::G5KAPI G5K Module} in an experiment.
This example implements the experiment described in
{https://www.grid5000.fr/mediawiki/index.php/Run_MPI_On_Grid%275000#Setting_up_and_starting_Open_MPI_to_use_high_performance_interconnect MPI on Grid5000}.
If you want to adapt it to another site, you have to verify that the properties are valid to the site in question.
For example, some sites do not have the filed 'ib20g' to YES, they probabily have instead 'ib10g'.

    require 'cute'
    require 'net/scp'


    g5k = Cute::G5KAPI.new()
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

* Sébastien Badia <sebastien.badia@inria.fr>
* Tomasz Buchert <tomasz.buchert@inria.fr>
* Emmanuel Jeanvoine <emmanuel.jeanvoine@inria.fr>
* Lucas Nussbaum <lucas.nussbaum@loria.fr>
* Luc Sarzyniec <luc.sarzyniec@inria.fr>
* Cristian Ruiz <cristian.ruiz@inria.fr>

Questions/comments should be directed to Lucas Nussbaum and Emmanuel Jeanvoine.
