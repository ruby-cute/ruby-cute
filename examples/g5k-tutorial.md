# @title Grid'5000 tutorial
# Grid'5000 tutorial


This tutorial aims at showing how **Ruby-Cute** can be used to
help the scripting of an experiment in the context of Grid'5000 testbed.
The programming language used as you would expect is {https://www.ruby-lang.org/en/ Ruby}.
We will use a powerful console debugger call {http://pryrepl.org/ Pry} which offer
several functionalities that can be used for the step by step scripting of complex experiments.

## Installing Ruby cute

The installation procedure is shown in {file:README.md Ruby-Cute install}.
After this step you will normally have `ruby-cute` and `pry` gems installed.

## Preparing the environment

Before using **Ruby-Cute** you have to create the following file:

    $ cat > ~/.grid5000_api.yml << EOF
    $ uri: https://api.grid5000.fr/
    $ version: sid
    $ EOF


Then, create a pair of SSH keys. This will be used for the first experiment.

    $ ssh-keygen -b 1024 -N "" -t rsa -f ~/my_ssh_jobkey

Let's create a directory for our experiments.

    $ mkdir ruby-cute-tutorial

## Getting acquainted with pry console

After instaling `ruby-cute` and `pry` gems you can lunch a pry console
with **ruby-cute** loaded by typing:


    $ cd ruby-cute-tutorial/
    $ cute

Which will open a `pry` console:

    [1] pry(main)>

In this console, we can evaluate Ruby code, execute shell commands, consult
documentation, explore classes and more.
The variable *$g5k* is available which can be used to access the Grid'5000 API through the
[G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API). For example,
let's request the name of the sites available in Grid'5000.
(Before starting be sure to set up a configuration file for the module, please refer to
[G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API))

    [2] pry(main)> $g5k.site_uids()
    => ["grenoble", "lille", "luxembourg", "lyon", "nancy", "nantes", "reims", "rennes", "sophia", "toulouse"]

We can consult the name of the cluster available in a specific site.

    [3] pry(main)> $g5k.cluster_uids("grenoble")
    => ["adonis", "edel", "genepi"]

As well as, the deployable environments:

    [6] pry(main)> $g5k.environment_uids("grenoble")
    => ["squeeze-x64-base", "squeeze-x64-big", "squeeze-x64-nfs", "wheezy-x64-base", "wheezy-x64-big", "wheezy-x64-min", "wheezy-x64-nfs", "wheezy-x64-xen"]

It is possible to execute shell commands, however all commands have to be prefixed with a dot ".". For example we could generate a pair of SSH keys using:

    [7] pry(main)> .ssh-keygen -b 1024 -N "" -t rsa -f ~/my_ssh_jobkey

Another advantage is the possibility of exploring the loaded Ruby modules.
Let's explore the [Cute](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute) module.

    [8] pry(main)> cd Cute
    [9] pry(Cute):1> ls
    constants: Bash  Execute  G5K  TakTuk  VERSION
    locals: _  __  _dir_  _ex_  _file_  _in_  _out_  _pry_

We can see that [Cute](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute) module
is composed of other helpful modules such as:
[G5K](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API),
[TakTuk](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/TakTuk), etc.

    [10] pry(main)> cd

Let's explore the methods defined in
[G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API),
so you can observe which methods can be used with `$g5k` variable.

    [11] pry(main)> ls Cute::G5K::API
    Object.methods: yaml_tag
    Cute::G5K::API#methods:
      check_deployment  deploy            environments     get_job      get_subnets   get_vlan_nodes  nodes_status  reserve  site_status  wait_for_deploy
      cluster_uids      deploy_status     g5k_user         get_jobs     get_switch    logger          release       rest     site_uids    wait_for_job
      clusters          environment_uids  get_deployments  get_my_jobs  get_switches  logger=         release_all   site     sites

We can access as well the respective YARD documentation of a given method by typing:

    [12] pry(main)> show-doc Cute::G5K::API#deploy

In the following section we will see how
`pry` can be used to setup an experiment step by step using **Ruby-Cute**.

## First experiment: Infiniband performance test

Here, we will use **Ruby-cute** to carry out an experiment.
For this particular experiment we have the following requirements:

- A pair of SSH keys
- Use of production environment (no deploy)
- Two nodes connected with infinaband (10G or 20G)
- MPI behchmark NETPIPE
- A MPI runtime (OpenMPI or MPICH)

We will do it interactibely using `pry`.
First, let's find the sites that offer Infinibad interconnection.
For that we will write a small script form `pry` console using the command edit.


    [13] pry(main)> edit -n find_infiniband.rb

This will open a new file with your prefered editor. Here we will put the following
ruby script:

    sites = $g5k.site_uids

    sites_infiniband = []

    sites.each do |site|
      sites_infiniband.push(site) unless $g5k.get_switches(site).select{ |t| t["model"] == "Infiniband" }.empty?
    end

Then, we execute it using `play` command which will execute line by line this script in the context of a Pry session.

    [21] pry(main)> play find_infiniband.rb
    => ["grenoble", "lille", "luxembourg", "lyon", "nancy", "nantes", "reims", "rennes", "sophia"]

We can observe that the variable `sites_infinibad` is now defined, telling us that Grenoble and Nancy sites offer Infiniband interconnection.

    [22] pry(main)> sites_infiniband
    => ["grenoble", "nancy"]

We send the keys that we have generated before to the chosen site:

    [22] pry(main)> .scp ~/my_ssh* nancy:~/

Now that we have found the sites that we can use, let's submit a job. You can use between grenoble and nancy site. If you
take a look at monika you will see that 'ib20g' for nancy and 'ib10g' in grenoble.
Given that the MPI bench uses just one MPI processes, we will need in realty
just one core of a given machine.
We will use OAR syntax to ask for two cores in two different nodes with ib20g in nancy.

    [23] pry(main)> job = $g5k.reserve(:site => "nancy", :resources => "{ib20g='YES'}/nodes=2/core=1",:walltime => '01:00:00', :keys => "~/my_ssh_jobkey" )
    2015-12-04 14:07:31.370 => Reserving resources: {ib20g='YES'}/nodes=2/core=1,walltime=01:00 (type: ) (in nancy)
    2015-12-04 14:07:41.358 => Waiting for reservation 692665
    2015-12-04 14:07:41.444 => Reservation 692665 should be available at 2015-12-04 14:07:34 +0100 (0 s)
    2015-12-04 14:07:41.444 => Reservation 692665 ready

A hash is returned containing all information about the job that we have just submitted.

    [58] pry(main)> job
    => {"uid"=>692665,
     "user_uid"=>"cruizsanabria",
     "user"=>"cruizsanabria",
     "walltime"=>3600,
     "queue"=>"default",
     "state"=>"running",
     "project"=>"default",
     "name"=>"rubyCute job",
     "types"=>[],
     "mode"=>"PASSIVE",
     "command"=>"sleep 3600",
     "submitted_at"=>1449234452,
     "scheduled_at"=>1449234454,
     "started_at"=>1449234454,
     "message"=>"FIFO scheduling OK",
     "properties"=>"(maintenance = 'NO') AND production = 'NO'",
     "directory"=>"/home/cruizsanabria",
     "events"=>[],
     "links"=>
       [{"rel"=>"self", "href"=>"/sid/sites/nancy/jobs/692665", "type"=>"application/vnd.grid5000.item+json"},
       {"rel"=>"parent", "href"=>"/sid/sites/nancy", "type"=>"application/vnd.grid5000.item+json"}],
     "resources_by_type"=>{"cores"=>["graphene-67.nancy.grid5000.fr", "graphene-45.nancy.grid5000.fr"]},
     "assigned_nodes"=>["graphene-67.nancy.grid5000.fr", "graphene-45.nancy.grid5000.fr"]}

An important information is the nodes that has been assigned, let's put this information in another variable:

    [60] pry(main)> nodes = job["assigned_nodes"]
    => ["graphene-67.nancy.grid5000.fr", "graphene-45.nancy.grid5000.fr"]

Then, we create a file with the name of the reserved machines:

    [62] pry(main)> machine_file = Tempfile.open('machine_file')
     => #<File:/tmp/machine_file20151204-28888-1ll3brs>

    [64] pry(main)> nodes.each{ |node| machine_file.puts node }
    => ["graphene-67.nancy.grid5000.fr", "graphene-45.nancy.grid5000.fr"]

    [66] pry(main)> machine_file.close


We will need to setup SSH options for OAR, we can do it with the {Cute::OARSSHoptions OARSSHoptions} class helper provided by ruby-cute:

    [6] pry(main)> grid5000_opt = OARSSHopts.new(:keys => "~/my_ssh_jobkey")
    => {:user=>"oar", :keys=>"~/my_ssh_jobkey", :port=>6667}

Now, we can communicate using SSH with our nodes. Lets send the machinefile using SCP.
From a `pry` console let's load the SCP module to transfer files:

    [12] pry(main)> require 'net/scp'

Then, let's open the editor with an empty file:

    [6] pry(main)> edit -t

and copy-paste the following code:

    Net::SCP.start(nodes.first, "oar", grid5000_opt) do |scp|
      scp.upload! machine_file.path, "/tmp/machine_file"
    end

If we save and quit the editor, the code will be evaluated in `pry` context. Therefore, in this case the file will be sent into the
first node. We can check this by performing an SSH connection into the node. We open the editor as we did before and type
the following code:

    Net::SSH.start(nodes.first, "oar", grid5000_opt) do |ssh|
      puts ssh.exec("cat /tmp/machine_file")
    end

Which will generate the following output:

    [12] pry(main)> edit -t
    #<Net::SSH::Connection::Channel:0x00000001247150>
    graphene-80.nancy.grid5000.fr
    graphene-81.nancy.grid5000.fr
    => nil

We confirmed the existence of the file in the first reserved node.
Now let's download, compile and execute
the benchmark. Create a Ruby file called netpipe:

    [12] pry(main)> edit -n netpipe.rb

With the following content:

    Net::SSH.start(nodes.first, "oar", grid5000_opt) do |ssh|
      netpipe_url = "http://pkgs.fedoraproject.org/repo/pkgs/NetPIPE/NetPIPE-3.7.1.tar.gz/5f720541387be065afdefc81d438b712/NetPIPE-3.7.1.tar.gz"
      ssh.exec!("mkdir -p netpipe_exp")
      ssh.exec!("export http_proxy=\"http://proxy:3128\"; wget -O ~/netpipe_exp/NetPIPE.tar.gz #{netpipe_url}")
      ssh.exec!("cd netpipe_exp && tar -zvxf NetPIPE.tar.gz")
      ssh.exec!("cd netpipe_exp/NetPIPE-3.7.1 && make mpi")
      ssh.exec("mpirun --mca plm_rsh_agent \"oarsh\" -machinefile /tmp/machine_file ~/netpipe_exp/NetPIPE-3.7.1/NPmpi")
    end

Then we execute this script:

    [16] pry(main)> play netpipe.rb
    #<Net::SSH::Connection::Channel:0x000000021679f0>
    Permission denied (publickey,keyboard-interactive).
    --------------------------------------------------------------------------
    A daemon (pid 4615) died unexpectedly with status 255 while attempting
    to launch so we are aborting.

    There may be more information reported by the environment (see above).

    This may be because the daemon was unable to find all the needed shared
    libraries on the remote node. You may set your LD_LIBRARY_PATH to have the
    location of the shared libraries on the remote nodes and this will
    automatically be forwarded to the remote nodes.
    --------------------------------------------------------------------------
    --------------------------------------------------------------------------
    mpirun noticed that the job aborted, but has no info as to the process
    that caused that situation.
    --------------------------------------------------------------------------
    mpirun: clean termination accomplished

    => nil

We got an error related to the SSH keys and it is due to the fact that `oarsh` cannot not find the appropriate key files.
We can fix this problem by prefixing the `mpirun` command with `export OAR_JOB_KEY_FILE=~/my_ssh_jobkey`.
Now the code will look like this:

    Net::SSH.start(nodes.first, "oar", grid5000_opt) do |ssh|
      netpipe_url = "http://pkgs.fedoraproject.org/repo/pkgs/NetPIPE/NetPIPE-3.7.1.tar.gz/5f720541387be065afdefc81d438b712/NetPIPE-3.7.1.tar.gz"
      ssh.exec!("mkdir -p netpipe_exp")
      ssh.exec!("export http_proxy=\"http://proxy:3128\"; wget -O ~/netpipe_exp/NetPIPE.tar.gz #{netpipe_url}")
      ssh.exec!("cd netpipe_exp && tar -zvxf NetPIPE.tar.gz")
      ssh.exec!("cd netpipe_exp/NetPIPE-3.7.1 && make mpi")
      ssh.exec("export OAR_JOB_KEY_FILE=~/my_ssh_jobkey;mpirun --mca plm_rsh_agent \"oarsh\" -machinefile /tmp/machine_file ~/netpipe_exp/NetPIPE-3.7.1/NPmpi")
    end

After running the script, it will show the output of the benchmark in the `pry` console:

    [34] pry(main)> play netpipe.rb
    #<Net::SSH::Connection::Channel:0x00000002edc6d0>
    0: adonis-9
    1: adonis-10
    Now starting the main loop
      0:       1 bytes  32103 times -->      4.58 Mbps in       1.67 usec
      1:       2 bytes  59994 times -->      9.22 Mbps in       1.65 usec
      2:       3 bytes  60440 times -->     13.79 Mbps in       1.66 usec
      3:       4 bytes  40180 times -->     18.34 Mbps in       1.66 usec
      4:       6 bytes  45076 times -->     27.07 Mbps in       1.69 usec
      5:       8 bytes  29563 times -->     36.16 Mbps in       1.69 usec
      6:      12 bytes  37023 times -->     53.84 Mbps in       1.70 usec
      7:      13 bytes  24500 times -->     57.97 Mbps in       1.71 usec
      8:      16 bytes  26977 times -->     71.61 Mbps in       1.70 usec
      9:      19 bytes  32995 times -->     84.65 Mbps in       1.71 usec
      10:      21 bytes  36882 times -->     93.27 Mbps in       1.72 usec
      11:      24 bytes  38808 times -->    106.69 Mbps in       1.72 usec
      12:      27 bytes  41271 times -->    119.77 Mbps in       1.72 usec

We can modify slightly the previous script to write the result into a file.
We need to use ssh.exec! to capture the output of the commands.

    Net::SSH.start(nodes.first, "oar", grid5000_opt) do |ssh|
      netpipe_url = "http://pkgs.fedoraproject.org/repo/pkgs/NetPIPE/NetPIPE-3.7.1.tar.gz/5f720541387be065afdefc81d438b712/NetPIPE-3.7.1.tar.gz"
      ssh.exec!("mkdir -p netpipe_exp")
      ssh.exec!("export http_proxy=\"http://proxy:3128\"; wget -O ~/netpipe_exp/NetPIPE.tar.gz #{netpipe_url}")
      ssh.exec!("cd netpipe_exp && tar -zvxf NetPIPE.tar.gz")
      ssh.exec!("cd netpipe_exp/NetPIPE-3.7.1 && make mpi")

      File.open("output_netpipe.txt", 'w') do |f|
        f.puts ssh.exec!("OAR_JOB_KEY_FILE=~/my_ssh_jobkey; mpirun --mca plm_rsh_agent \"oarsh\" -machinefile /tmp/machine_file ~/netpipe_exp/NetPIPE-3.7.1/NPmpi")
      end
    end

We can check the results by doing:

    [16] pry(main)> .cat output_netpipe.txt
    0: adonis-9
    1: adonis-10
    Now starting the main loop
     0:       1 bytes  31441 times -->      4.62 Mbps in       1.65 usec
     1:       2 bytes  60550 times -->      9.24 Mbps in       1.65 usec
     2:       3 bytes  60580 times -->     13.87 Mbps in       1.65 usec
     3:       4 bytes  40404 times -->     18.39 Mbps in       1.66 usec
     4:       6 bytes  45183 times -->     27.22 Mbps in       1.68 usec
     5:       8 bytes  29729 times -->     36.17 Mbps in       1.69 usec
     6:      12 bytes  37039 times -->     54.01 Mbps in       1.70 usec
     7:      13 bytes  24578 times -->     58.40 Mbps in       1.70 usec
     8:      16 bytes  27177 times -->     71.87 Mbps in       1.70 usec
     9:      19 bytes  33116 times -->     85.00 Mbps in       1.71 usec
