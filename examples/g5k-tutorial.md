# @title Grid'5000 tutorial
# Grid'5000 tutorial


This tutorial aims at showing how **Ruby-Cute** can be used to
help the scripting of an experiment in the context of the Grid'5000 testbed.
The programming language used, as you would expect, is {https://www.ruby-lang.org/en/ Ruby}.
We will use a powerful console debugger called {http://pryrepl.org/ Pry} which offers
several functionalities that can be used for the step-by-step scripting of complex experiments.

In this tutorial the first two sections are dedicated to the installation and basic use of **Ruby-Cute**.
You can skip those sections if you are already acquainted with **Ruby-Cute**.
The other sections show how to use **Ruby-cute** for scripting complex experiments.
This is shown through three examples:

1. **Infiniband performance test**: the experiment will illustrate how to perform a reservation,
   the execution of commands in a reserved node  and it explains several `pry` commands that will help you with the writing of your experiment.
2. **Running NAS benchmarks in Grid’5000**: you will get acquainted with parallel execution using simple SSH or {http://taktuk.gforge.inria.fr/ TakTuk}.
3. **Performing network measures within a reserved VLAN**: you will learn how to reserve a routed VLAN
   and to query the G5K metrology {https://www.grid5000.fr/mediawiki/index.php/API API}.
   For this particular experiment we will query the {https://www.grid5000.fr/mediawiki/index.php/Monitoring Kwapi} service.

The aforementioned experiments are independent, you can perform them in any order.
However, you may need some concepts that are explained only in specific sections.

## Installing and preparing Ruby cute

The installation procedure is shown in {file:README.md Ruby-Cute install}.
After this step you will normally have `ruby-cute` and `pry` gems installed.

Before using **Ruby-Cute** you have to create the following file:

    $ cat > ~/.grid5000_api.yml << EOF
    $ uri: https://api.grid5000.fr/
    $ version: 3.0
    $ EOF

## Getting acquainted with the pry console

After instaling `ruby-cute` and `pry` gems you can lunch a pry console
with **ruby-cute** loaded by typing:

    $ cute

Which will open a `pry` console:

    [1] pry(main)>

In this console, we can evaluate Ruby code, execute shell commands, consult
documentation, explore classes and more.
The variable *$g5k* is available which can be used to access the Grid'5000 API through the
[G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API). For example,
let's request the name of the sites available in Grid'5000.

    [2] pry(main)> $g5k.site_uids()
    => ["grenoble", "lille", "luxembourg", "lyon", "nancy", "nantes", "reims", "rennes", "sophia", "toulouse"]

We can consult the name of the clusters available in a specific site.

    [3] pry(main)> $g5k.cluster_uids("grenoble")
    => ["adonis", "edel", "genepi"]

It is possible to execute shell commands, however all commands have to be prefixed with a dot ".". For example we could generate a pair of SSH keys using:

    [7] pry(main)> .ssh-keygen -b 1024 -N "" -t rsa -f ~/my_ssh_jobkey

Another advantage is the possibility of exploring the loaded Ruby modules.
Let's explore the [Cute](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute) module.

    [8] pry(main)> cd Cute
    [9] pry(Cute):1> ls
    constants: Bash  Execute  G5K  TakTuk  VERSION
    locals: _  __  _dir_  _ex_  _file_  _in_  _out_  _pry_

We can see that the [Cute](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute) module
is composed of other helpful modules such as:
[G5K](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API),
[TakTuk](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/TakTuk), etc.
To quit the Cute namespace type:

    [10] pry(main)> cd

Let's explore the methods defined in the
[G5K Module](http://www.rubydoc.info/github/ruby-cute/ruby-cute/master/Cute/G5K/API),
so you can observe which methods can be used with `$g5k` variable.

    [11] pry(main)> ls Cute::G5K::API
    Object.methods: yaml_tag
    Cute::G5K::API#methods:
      check_deployment  deploy            environments     get_job      get_subnets   get_vlan_nodes  nodes_status  reserve  site_status  wait_for_deploy
      cluster_uids      deploy_status     g5k_user         get_jobs     get_switch    logger          release       rest     site_uids    wait_for_job
      clusters          environment_uids  get_deployments  get_my_jobs  get_switches  logger=         release_all   site     sites

We can access the respective YARD documentation of a given method by typing:

    [12] pry(main)> show-doc Cute::G5K::API#deploy

In the following section we will see how
`pry` can be used to setup an experiment step by step using **Ruby-Cute**.

Pry can be customized by creating the file `.pryrc`. We will create this
file with the following content in order to choose our prefered editor:

    $ cat > ~/.pryrc << EOF
    Pry.config.editor = "emacs"
    EOF

## First experiment: Infiniband performance test

Here, we will use **Ruby-cute** to carry out an experiment.
In this experiment, we will ask for two nodes equipped with infiniband and
then, we will perform some performance test using a network benchmark called
[NETPIPE](http://bitspjoule.org/netpipe/).
NETPIPE performs simple ping-pong tests, bouncing messages of increasing size between two processes.
Message sizes are chosen at regular intervals, and with slight perturbations, to provide a complete test of the communication system.
For this particular experiment we have the following requirements:

- A pair of SSH keys
- Use of standard environment (no deploy)
- Two nodes connected with infiniband (10G or 20G)
- MPI benchmark NETPIPE
- A MPI runtime (OpenMPI or MPICH)

We will do it interactively using `pry`.
Let's create a directory for keeping all the scripts that we will write throughout the tutorial.

    $ mkdir ruby-cute-tutorial

Then, we execute the `pry` console form this directory:

    $ cd ruby-cute-tutorial
    $ cute

First, let's find the sites that offer Infiniband interconnection.
For that we will write a small script from `pry` console using the command edit.


    [13] pry(main)> edit -n find_infiniband.rb

This will open a new file with your prefered editor. Here we will put the following
ruby script:

    sites = $g5k.site_uids

    sites_infiniband = []

    sites.each do |site|
      sites_infiniband.push(site) unless $g5k.get_switches(site).select{ |t| t["model"] == "Infiniband" }.empty?
    end

Then, we execute it using the `play` command which will execute line by line this script in the context of a Pry session.

    [21] pry(main)> play find_infiniband.rb

We can observe that the variable `sites_infiniband` is now defined, telling us that Grenoble and Nancy sites offer Infiniband interconnection.

    [22] pry(main)> sites_infiniband
    => ["grenoble", "nancy"]

Then, create a pair of SSH keys (Necessary for OARSSH):

    [23] pry(main)> .ssh-keygen -b 1024 -N "" -t rsa -f ~/my_ssh_jobkey

We send the generated keys to the chosen site (ssh configuration has be set up for the following command to work,
see [SSH Configuration](https://www.grid5000.fr/mediawiki/index.php/SSH_and_Grid%275000) for more information):

    [24] pry(main)> .scp ~/my_ssh* nancy:~/

Now that we have found the sites, let's submit a job. You can use between Grenoble and Nancy sites. If you
take a look at {https://www.grid5000.fr/mediawiki/index.php/Status Monika} you will see that in Nancy we should use the OAR property 'ib20g' and in Grenoble we should use 'ib10g'.
Given that the MPI bench uses just one MPI process, we will need in realty just one core of a given machine.
We will use OAR syntax to ask for two cores in two different nodes with ib10g in Grenoble.

    [25] pry(main)> job = $g5k.reserve(:site => "nancy", :resources => "{ib20g='YES'}/nodes=2/core=1",:walltime => '01:00:00', :keys => "~/my_ssh_jobkey" )
    2015-12-04 14:07:31.370 => Reserving resources: {ib20g='YES'}/nodes=2/core=1,walltime=01:00 (type: ) (in nancy)
    2015-12-04 14:07:41.358 => Waiting for reservation 692665
    2015-12-04 14:07:41.444 => Reservation 692665 should be available at 2015-12-04 14:07:34 +0100 (0 s)
    2015-12-04 14:07:41.444 => Reservation 692665 ready

A hash is returned containing all the information about the job that we have just submitted.

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


We will need to setup SSH options for OAR, we can do it with the {Cute::OARSSHopts OARSSHopts} class helper provided by ruby-cute:

    [6] pry(main)> grid5000_opt = Cute::OARSSHopts.new(:keys => "~/my_ssh_jobkey")
    => {:user=>"oar", :keys=>"~/my_ssh_jobkey", :port=>6667}

Now, we can communicate using SSH with our nodes. Let's send the machinefile using SCP.
From a `pry` console let's load the SCP module to transfer files:

    [12] pry(main)> require 'net/scp'

Then, copy-paste the following code in pry console:

    Net::SCP.start(nodes.first, "oar", grid5000_opt) do |scp|
      scp.upload! machine_file.path, "/tmp/machine_file"
    end

The previous code will sent the machine file into the first node.
We can check this by performing an SSH connection into the node.
Here to illustrate the use of temporary files, let's type the following:

    [6] pry(main)> edit -t

and copy-paste the following code:

    Net::SSH.start(nodes.first, "oar", grid5000_opt) do |ssh|
      puts ssh.exec("cat /tmp/machine_file")
    end

If we save and quit the editor, the code will be evaluated in Pry context.
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
      ssh.exec!("wget -O ~/netpipe_exp/NetPIPE.tar.gz #{netpipe_url}")
      ssh.exec!("cd netpipe_exp && tar -zvxf NetPIPE.tar.gz")
      ssh.exec!("cd netpipe_exp/NetPIPE-3.7.1 && make mpi")
      ssh.exec("mpirun --mca plm_rsh_agent \"oarsh\" -machinefile /tmp/machine_file ~/netpipe_exp/NetPIPE-3.7.1/NPmpi")
    end

Then, execute the created script:

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
      ssh.exec!("wget -O ~/netpipe_exp/NetPIPE.tar.gz #{netpipe_url}")
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
We need to use `ssh.exec!` to capture the output of the commands.

    Net::SSH.start(nodes.first, "oar", grid5000_opt) do |ssh|
      netpipe_url = "http://pkgs.fedoraproject.org/repo/pkgs/NetPIPE/NetPIPE-3.7.1.tar.gz/5f720541387be065afdefc81d438b712/NetPIPE-3.7.1.tar.gz"
      ssh.exec!("mkdir -p netpipe_exp")
      ssh.exec!("wget -O ~/netpipe_exp/NetPIPE.tar.gz #{netpipe_url}")
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

The latency is given by the last column for a 1 byte message; the maximum throughput is given by the last line.
Once finished, we could release the job:

    [34] pry(main)> $g5k.release(job)
    => ""

At the end of the experiment you can use the command `hist` to see what you have done so far.
This can help you to assemble everything together in a whole script.

    [22] pry(main)> hist
    1: edit -n find_infiniband.rb
    3: play find_infiniband.rb
    4: sites_infiniband
    5: .ls ~/my_ssh*
    6: .scp ~/my_ssh* nancy:~/
    7: job = $g5k.reserve(:site => "nancy", :resources => "{ib20g='YES'}/nodes=2/core=1",:walltime => '01:00:00', :keys => "~/my_ssh_jobkey" )
    8: nodes = job["assigned_nodes"]
    9: machine_file = Tempfile.open('machine_file')
    10: nodes.each{ |node| machine_file.puts node }
    11: machine_file.close
    12: grid5000_opt = OARSSHopts.new(:keys => "~/my_ssh_jobkey")
    13: require 'net/scp'
    14: Net::SCP.start(nodes.first, "oar", grid5000_opt) do |scp|
    15:  scp.upload! machine_file.path, "/tmp/machine_file"
    16: end
    17: edit -n netpipe.rb
    18: play netpipe.rb
    19: edit -n netpipe.rb
    20: play netpipe.rb

## Running NAS benchmarks in Grid'5000: getting acquainted with parallel command execution

In this experiment, we will run the NAS benchmarks in Grid'5000 and we will script a scalability test for one of the benchmarks.
The NAS Parallel Benchmarks (NPB) are a set of benchmarks targeting performance evaluation of highly parallel supercomputers.
These benchmarks gather parallel kernels and three simluated applications.
They mimic the workload of large scale computational fluid dynamic applications.
The objective of this tutorial is to perform a scalability test of the NAS benchmarks. We are going to study how the
number of computing units used during the computation reduce the execution time of the application.
This experiment has the following requirements:

- 4 or 2 nodes from any Grid'5000 sites
- Use of standard environment (no deploy)
- NAS MPI behchmark
- A MPI runtime (OpenMPI or MPICH)

If you have not created a directory for the tutorial, create it and execute the `pry` console from there:

    $ mkdir ruby-cute-tutorial
    $ cd ruby-cute-tutorial
    $ cute

First, let's find the necessary nodes for our experiment. As resources in Grid'5000 could be very busy, we are going
to script a loop that will explore all Grid'5000 sites and find the first site that can provide us with the required nodes.
Open an editor form `pry` console:

    [5] pry(main)> edit -n find_nodes.rb

and type the following code:

    sites = $g5k.site_uids
    job = {}

    sites.each do |site|
      job = $g5k.reserve(:site => site, :nodes => 4, :wait => false, :walltime => "01:00:00")
      begin
        job = $g5k.wait_for_job(job, :wait_time => 60)
        puts "Nodes assigned #{job['assigned_nodes']}"
        break
      rescue  Cute::G5K::EventTimeout
        puts "We waited too long in site #{site} let's release the job and try in another site"
        $g5k.release(job)
      end
    end

Here, we use the method {Cute::G5K::API#site_uids site_uids} for getting all available sites.
Then, a job is submitted using the method {Cute::G5K::API#reserve reserve}.
We ask for 4 nodes in a given site and we set the parameter `wait` to false which makes the method to return immediately.
Then, we use {Cute::G5K::API#wait_for_job wait_for_job} to set a timeout. If the timeout is reached a {Cute::G5K::EventTimeout Timeout} exception will be triggered
that we catch in order to consequently release the submitted job and try to submit it in another site.
Let's execute the script using `play` command:

    [8] pry(main)> play find_nodes.rb
    2015-12-08 16:50:35.582 => Reserving resources: /nodes=4,walltime=01:00 (type: ) (in grenoble)
    2015-12-08 16:50:36.465 => Waiting for reservation 1702197
    2015-12-08 16:50:41.587 => Reservation 1702197 should be available at 2015-12-08 16:50:37 +0100 (0 s)
    2015-12-08 16:50:41.587 => Reservation 1702197 ready
    Nodes assigned ["edel-10.grenoble.grid5000.fr", "edel-11.grenoble.grid5000.fr", "edel-12.grenoble.grid5000.fr", "edel-13.grenoble.grid5000.fr"]
    => nil

The variable `job` is updated in Pry context. When no keys are specified, the option *-allow_classic_ssh* is activated
which enables the access via default SSH to the reserved machines. You can verify it by doing:

    [11] pry(main)> .ssh edel-11.grenoble.grid5000.fr "hostname"
    Warning: Permanently added 'edel-11.grenoble.grid5000.fr,172.16.17.11' (RSA) to the list of known hosts.
    edel-11.grenoble.grid5000.fr

Let's explore the available modules for the parallel execution of commands in several remote machines.
The following example shows how to use the {Cute::TakTuk TakTuk} module.

    nodes = job["assigned_nodes"]
    Cute::TakTuk.start(nodes) do |tak|
       tak.exec("hostname")
    end

Which generates as output:

    edel-10.grenoble.grid5000.fr/output/0:edel-10.grenoble.grid5000.fr
    edel-12.grenoble.grid5000.fr/output/0:edel-12.grenoble.grid5000.fr
    edel-13.grenoble.grid5000.fr/output/0:edel-13.grenoble.grid5000.fr
    edel-10.grenoble.grid5000.fr/status/0:0
    edel-11.grenoble.grid5000.fr/output/0:edel-11.grenoble.grid5000.fr
    edel-12.grenoble.grid5000.fr/status/0:0
    edel-13.grenoble.grid5000.fr/status/0:0
    edel-11.grenoble.grid5000.fr/status/0:0

The following example shows how to use the {Net::SSH::Multi Net::SSH::Multi} module.

    Net::SSH::Multi.start do |session|
      nodes.each{ |node| session.use node }
      session.exec("hostname")
    end

If we type that into pry console we will get:

    [edel-10.grenoble.grid5000.fr] edel-10.grenoble.grid5000.fr
    [edel-11.grenoble.grid5000.fr] edel-11.grenoble.grid5000.fr
    [edel-12.grenoble.grid5000.fr] edel-12.grenoble.grid5000.fr
    [edel-13.grenoble.grid5000.fr] edel-13.grenoble.grid5000.fr

It is possible to capture the output of the executed command by adding **!** to exec method.
For example, let's find the number of cores available in the reserved machines:

    results = {}
    Net::SSH::Multi.start do |session|
      nodes.each{ |node| session.use node }
      results = session.exec!("nproc")
    end

The {Net::SSH::Multi::SessionActions#exec! exec!} method will return a Hash that looks like this:

    [27] pry(main)> results
    => {"edel-10.grenoble.grid5000.fr"=>{:stdout=>"8", :status=>0},
    "edel-11.grenoble.grid5000.fr"=>{:stdout=>"8", :status=>0},
    "edel-12.grenoble.grid5000.fr"=>{:stdout=>"8", :status=>0},
    "edel-13.grenoble.grid5000.fr"=>{:stdout=>"8", :status=>0}}

Where the Hash keys are the names of the machines and the values correspond to the output of the commands.
Then, we can easily get the total number of cores by typing:

    [11] pry(main)> num_cores = results.values.inject(0){ |sum, item| sum+item[:stdout].to_i}
     => 32

Another way to do that is to use the information given by the G5K API regarding the submitted job:

     [36] pry(main)> job["resources_by_type"]["cores"].length
     => 32

Let's create a machine file that we will need later on for our experiments:

     machine_file = Tempfile.open('machine_file')
     nodes.each{ |node| machine_file.puts node }
     machine_file.close

After creating the machine file, we need to send it to the other machines.
Additionally, we need to download and compile the benchmark.
Let's write a small script that help us to perform the aforementioned tasks.
Open the editor in pry console:

     [17] pry(main)> edit -n NAS-expe.rb

Then, type:

     SOURCE_NAS = "http://public.rennes.grid5000.fr/~cruizsanabria/NPB3.3.tar"

     `wget #{SOURCE_NAS} -O /tmp/NAS.tar`

     Cute::TakTuk.start(nodes) do |tak|

       tak.put(machine_file.path, "machine_file")
       tak.put("/tmp/NAS.tar", "/tmp/NAS.tar")

       tak.exec!("cd /tmp/; tar -xvf NAS.tar")
       puts tak.exec!("make lu NPROCS=#{num_cores} CLASS=A MPIF77=mpif77 -C /tmp/NPB3.3/NPB3.3-MPI/")

     end

We can observe in the previous snippet of code that {Cute::TakTuk TakTuk} module can be used to
transfer files to several remote nodes. {Cute::TakTuk::TakTuk#put put} and {Cute::TakTuk::TakTuk#exec exec} methods
can be used in the same block. Finally, execute the script:

     [102] pry(main)> play NAS-expe.rb

We can check if each node has the generated binary and the machine file:

     Net::SSH::Multi.start do |session|
       nodes.each{ |node| session.use node }
       session.exec("ls /tmp/NPB3.3/NPB3.3-MPI/bin/")
       session.exec("ls ~/machine*")
     end

After typing it into `pry` console we will get something like:

    [genepi-27.grenoble.grid5000.fr] lu.A.32
    [genepi-29.grenoble.grid5000.fr] lu.A.32
    [genepi-29.grenoble.grid5000.fr] /home/cruizsanabria/machine_file
    [genepi-19.grenoble.grid5000.fr] lu.A.32
    [genepi-19.grenoble.grid5000.fr] /home/cruizsanabria/machine_file
    [genepi-2.grenoble.grid5000.fr] lu.A.32
    [genepi-2.grenoble.grid5000.fr] /home/cruizsanabria/machine_file
    [genepi-27.grenoble.grid5000.fr] /home/cruizsanabria/machine_file

Which confirms the presence of both files on the nodes.
We can get the path of the binary by typing the following into `pry` console.

     Net::SSH::Multi.start do |session|
       nodes.each{ |node| session.use node }
       results = session.exec!("find /tmp/ -name lu.A.32")
     end

We will get some errors caused by the `find` command:

     [32] pry(main)> results
     => {"genepi-27.grenoble.grid5000.fr"=>{:stdout=>"/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32", :stderr=>": Permission denied", :status=>1},
     "genepi-29.grenoble.grid5000.fr"=>{:stdout=>"/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32", :stderr=>": Permission denied", :status=>1},
     "genepi-19.grenoble.grid5000.fr"=>{:stderr=>": Permission denied", :stdout=>"/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32", :status=>1},
     "genepi-2.grenoble.grid5000.fr"=>{:stdout=>"/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32", :stderr=>": Permission denied", :status=>1}}


Then, we can assign this to a new variable:

     [33] pry(main)> lu_path = results.values.first[:stdout]
     => "/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32"

The setup of the experiment is done. It is time to execute the benchmark by typing the following into `pry` console:

    Net::SSH.start(nodes.first) do |ssh|
      results = ssh.exec!("mpirun --mca btl self,sm,tcp -np 32 --machinefile machine_file #{lu_path}")
    end

Let's now perform a scalability test of the LU application for 2, 4, 8, 16, 32 processes. Open the editor:

    [100] pry(main)> edit -n scalability_NAS.rb

And copy-paste the following script:

    num_cores = [2,4,8,16,32]

    Cute::TakTuk.start(nodes) do |tak|

      num_cores.each do |cores|
        puts tak.exec!("make lu NPROCS=#{cores} CLASS=A MPIF77=mpif77 -C /tmp/NPB3.3/NPB3.3-MPI/")
      end

      results = tak.exec!("find /tmp/ -name lu.A.*")
    end

    binaries = results.values.first[:output].split("\n")

    expe_res = {}

    Net::SSH.start(nodes.first) do |ssh|
      binaries.each do |binary|
        processes = /A\.(\d*)/.match(binary)[1]
        expe_res[processes]= {}
        result = ssh.exec!("mpirun --mca btl self,sm,tcp -np #{processes} --machinefile machine_file #{binary}")
        expe_res[processes][:output]= result
        expe_res[processes][:time] =result.split("\n").select{ |t| t["Time in"]}.first
      end
    end

Then, we execute it:

    [102] pry(main)> play scalability_NAS.rb

It will take approximately 2 ~ 3 minutes to run. After finishing a new Hash will
be defined called *expe_res* that we can use to print the results:

    num_cores.each{ |cores| puts "#{cores} cores: #{expe_res[cores.to_s][:time]}"}

It will generate:

    [107] pry(main)> num_cores.each{ |cores| puts "#{cores} cores: #{expe_res[cores.to_s][:time]}"}
    2 cores:  Time in seconds =                    42.93
    4 cores:  Time in seconds =                    26.50
    8 cores:  Time in seconds =                    12.39
    16 cores:  Time in seconds =                     7.01
    32 cores:  Time in seconds =                     6.00

Finally, we can use the command `hist` to try to assemble all we have done so far into a script.
Once finished, we could release the job:

    [34] pry(main)> $g5k.release(job)
    => ""

## Performing network measurements within a reserved VLAN

In this experiment, we will perform network measurements between two nodes located in different Grid'5000 sites.
The network measurements will be carried out in an isolated VLAN.
We will first reserved two nodes located in two different Grid'5000 sites in deploy mode and we will ask for two routed VLANs.
Once the nodes are ready, an environment will be deployed and the application iperf will be install in all nodes.
Then, we will perform some network measurements among the nodes.
Finally, we will query the KWAPI using the G5K metrology API to get the network traffic generated during our experiment.

This experiment has the following requirements:

- Two nodes in two different G5K sites
- Environment deployment
- VLAN reservation
- Iperf application
- Access to Network traffic data.

If you have not created a directory for the tutorial, create it and execute the `pry` console from there:

    $ mkdir ruby-cute-tutorial
    $ cd ruby-cute-tutorial
    $ cute

Let's create a small script that will help us with the reservation of nodes.
Open the `pry` editor:

    [35] pry(main)> edit -n multisite.rb

and type:

    jobs = {}
    threads = []
    ["nancy","rennes"].each do |site|

      threads.push<< Thread.new do

        jobs[site] = job = $g5k.reserve(:site => site, :nodes => 1,
                                   :env => 'jessie-x64-min',
                                   :vlan => :routed)
      end
    end

    threads.each{ |t| t.join}


In the script, we have chosen Nancy and Rennes sites. You are encouraged to try other sites as the number of routed VLANs is limited in each site.
For the purpose of this tutorial you have to choose a site where Kwapi is available: Grenoble, Nancy, Rennes, Lyon, Nantes.
We use the method {Cute::G5K::API#reserve reserve} with parameter *env* for specifying the environment we want to deploy.
This will automatically submit a deploy job and it will deploy the specified environment.
The parameter *vlan* will additionally reserve a VLAN and pass it to Kadeploy to setup the VLAN.
After executing this small script we got:

    [36] pry(main)> play multisite.rb
    2016-01-20 12:48:15.010 => Reserving resources: {type='kavlan'}/vlan=1+/nodes=1,walltime=01:00 (type: deploy) (in nancy)
    2016-01-20 12:48:15.010 => Reserving resources: {type='kavlan'}/vlan=1+/nodes=1,walltime=01:00 (type: deploy) (in rennes)
    2016-01-20 12:48:16.145 => Waiting for reservation 740698
    2016-01-20 12:48:16.246 => Waiting for reservation 802917
    2016-01-20 12:48:21.270 => Reservation 740698 should be available at 2016-01-20 12:48:17 +0100 (0 s)
    2016-01-20 12:48:26.344 => Reservation 740698 should be available at 2016-01-20 12:48:17 +0100 (0 s)
    2016-01-20 12:48:26.404 => Reservation 802917 should be available at 2016-01-20 12:48:13 +0100 (0 s)
    2016-01-20 12:48:26.404 => Reservation 802917 ready
    2016-01-20 12:48:26.541 => Found VLAN with uid = 4
    2016-01-20 12:48:26.541 => Creating deployment
    2016-01-20 12:48:27.256 => Waiting for 1 deployment
    2016-01-20 12:48:31.296 => Waiting for 1 deployment
    2016-01-20 12:48:31.406 => Reservation 740698 should be available at 2016-01-20 12:48:17 +0100 (0 s)
    2016-01-20 12:48:31.406 => Reservation 740698 ready
    2016-01-20 12:48:31.469 => Found VLAN with uid = 4
    2016-01-20 12:48:31.469 => Creating deployment
    2016-01-20 12:48:31.869 => Waiting for 1 deployment
    2016-01-20 12:48:35.414 => Waiting for 1 deployment

At the end of the process the variable `jobs` will be defined and it will contain the jobs' information in each site.
In this variable, we can find information related with the deployment.

    [44] pry(main)> jobs["nancy"]["deploy"]
    => [{"created_at"=>1450439620,
    "environment"=>"jessie-x64-min",
    "key"=>"https://api.grid5000.fr/sid/sites/nancy/files/cruizsanabria-key-84f3f1dbb1279bc1bddcd618e26c960307d653c5",
    "nodes"=>["graphite-4.nancy.grid5000.fr"],
    "result"=>{"graphite-4.nancy.grid5000.fr"=>{"macro"=>nil, "micro"=>nil, "state"=>"OK"}},
    "site_uid"=>"nancy",
    "status"=>"terminated",
    "uid"=>"D-b026879e-b185-4e20-8bc5-ea0842a6954b",
    "updated_at"=>1450439860,
    "user_uid"=>"cruizsanabria",
    "vlan"=>14,
    "links"=>
    [{"rel"=>"self", "href"=>"/sid/sites/nancy/deployments/D-b026879e-b185-4e20-8bc5-ea0842a6954b", "type"=>"application/vnd.grid5000.item+json"},
    		     {"rel"=>"parent", "href"=>"/sid/sites/nancy", "type"=>"application/vnd.grid5000.item+json"}]}]

Some important information are: the status of the whole process and the state per node.
We can use this information to check if the deployment have finished successfully in all nodes.
This data structure is used by the method {Cute::G5K::API#check_deployment check_deployment}.
Let's check the documentation of this method:

    [16] pry(main)> show-doc Cute::G5K::API#check_deployment

    From: /home/cruizsanabria/Repositories/ruby-cute/lib/cute/g5k_api.rb @ line 1198:
    Owner: Cute::G5K::API
    Visibility: public
    Signature: check_deployment(deploy_info)
    Number of lines: 10

    It returns an array of machines that did not deploy successfully
    = Example
    It can be used to try a new deploy:

       badnodes = g5k.check_deployment(job["deploy"].last)
       g5k.deploy(job,:nodes => badnodes, :env => 'wheezy-x64-base')
       g5k.wait_for_deploy(job)

       return [Array] machines that did not deploy successfully
       param deploy_info [Hash] deployment structure information

We can use this method with the jobs we have just submitted
(The output will be probably long, so you will need to scroll up to see what it is shown here):

    [47] pry(main)> jobs.each{ |site,job| puts "all nodes OK in site: #{site}" if $g5k.check_deployment(job["deploy"].last).empty?}
    all nodes OK in site: rennes
    all nodes OK in site: nancy

Now, the reserved nodes are in a VLAN; within this VLAN a DHCP server will assign new IP addresses to the nodes.
You can configure your own if you want (please refer to {https://www.grid5000.fr/mediawiki/index.php/Network_isolation_on_Grid%275000 KVLAN tutorial}
if you want to know more). We can get the new assigned names by doing:

    nodes = []
    jobs.each{ |site,job| nodes.push($g5k.get_vlan_nodes(job))}

After putting that into `pry` we will get something like this:

    [50] pry(main)> nodes
    => [["paranoia-6-kavlan-16.rennes.grid5000.fr"], ["graphite-4-kavlan-14.nancy.grid5000.fr"]]

    [51] pry(main)> nodes.flatten
    => ["paranoia-6-kavlan-16.rennes.grid5000.fr", "graphite-4-kavlan-14.nancy.grid5000.fr"]

Now, let's install `iperf` application in order to perform our network measurements.
Copy-paste the following code into `pry`:

    nodes = nodes.flatten

    Net::SSH::Multi.start do |session|
      nodes.each{ |node| session.use("root@#{node}") }
      session.exec!("apt-get update")
      session.exec("DEBIAN_FRONTEND=noninteractive apt-get install -q -y iperf")
    end

You should get something like this:

    [paranoia-6-kavlan-16.rennes.grid5000.fr] Reading package lists...
    [paranoia-6-kavlan-16.rennes.grid5000.fr] Building dependency tree...
    [graphite-4-kavlan-14.nancy.grid5000.fr] Reading package lists...
    [graphite-4-kavlan-14.nancy.grid5000.fr] Building dependency tree...
    [paranoia-6-kavlan-16.rennes.grid5000.fr]
    [paranoia-6-kavlan-16.rennes.grid5000.fr] Reading state information...
    [paranoia-6-kavlan-16.rennes.grid5000.fr] The following NEW packages will be installed:
    [paranoia-6-kavlan-16.rennes.grid5000.fr]   iperf
    [paranoia-6-kavlan-16.rennes.grid5000.fr] 0 upgraded, 1 newly installed, 0 to remove and 8 not upgraded.
    [paranoia-6-kavlan-16.rennes.grid5000.fr] Need to get 51.4 kB of archives.
    [paranoia-6-kavlan-16.rennes.grid5000.fr] After this operation, 179 kB of additional disk space will be used.
    [paranoia-6-kavlan-16.rennes.grid5000.fr] Get:1 http://ftp.debian.org/debian/ jessie/main iperf amd64 2.0.5+dfsg1-2 [51.4 kB]
    [graphite-4-kavlan-14.nancy.grid5000.fr]
    [graphite-4-kavlan-14.nancy.grid5000.fr] Reading state information...
    [graphite-4-kavlan-14.nancy.grid5000.fr] The following NEW packages will be installed:
    [graphite-4-kavlan-14.nancy.grid5000.fr]   iperf


You can check if the application has been successfully installed,
by typing the following into the `pry` console:

    Net::SSH::Multi.start do |session|
      nodes.each{ |node| session.use("root@#{node}") }
      session.exec("iperf --version")
    end

Which will generate:

    [65] pry(main)* end
    [paranoia-6-kavlan-16.rennes.grid5000.fr] iperf version 2.0.5 (08 Jul 2010) pthreads
    [graphite-4-kavlan-14.nancy.grid5000.fr] iperf version 2.0.5 (08 Jul 2010) pthreads
    => nil

Let's perform some iperf tests, let's write a small script.
Open the editor:

    [76] pry(main)> edit -n iperf_test.rb

and type:

    results = {}

    Net::SSH::Multi.start do |session|

      session.group :server do
        session.use("root@#{nodes[0]}")
      end

      session.group :client do
        session.use("root@#{nodes[1]}")
      end

      session.with(:server).exec("iperf -s &")

      #bandwith

      results[:bandwidth]= session.with(:client).exec!("iperf -c #{nodes[0]}")

     # bi-directional bandwidth measurement

      results[:bidi]= session.with(:client).exec!("iperf -c #{nodes[0]} -r")

     # TCP windows size
      results[:window]= session.with(:client).exec!("iperf -c #{nodes[0]} -w 2000")

     # shutdown server

      session.with(:server).exec("skill iperf")
    end

Then, if we execute it with the `play` command:


    [77] pry(main)> play iperf_test.rb
    [paranoia-6-kavlan-16.rennes.grid5000.fr] ------------------------------------------------------------
    [paranoia-6-kavlan-16.rennes.grid5000.fr] Server listening on TCP port 5001
    [paranoia-6-kavlan-16.rennes.grid5000.fr] TCP window size: 85.3 KByte (default)
    [paranoia-6-kavlan-16.rennes.grid5000.fr] ------------------------------------------------------------
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [  4] local 10.27.204.71 port 5001 connected with 10.19.200.240 port 32769
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [ ID] Interval       Transfer     Bandwidth
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [  4]  0.0-10.0 sec  1.12 GBytes   957 Mbits/sec
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [  5] local 10.27.204.71 port 5001 connected with 10.19.200.240 port 32770
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [  5]  0.0-10.0 sec  1.10 GBytes   947 Mbits/sec
    [paranoia-6-kavlan-16.rennes.grid5000.fr] ------------------------------------------------------------
    [paranoia-6-kavlan-16.rennes.grid5000.fr] Client connecting to 10.19.200.240, TCP port 5001
    [paranoia-6-kavlan-16.rennes.grid5000.fr] TCP window size: 85.0 KByte (default)
    [paranoia-6-kavlan-16.rennes.grid5000.fr] ------------------------------------------------------------
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [  5] local 10.27.204.71 port 47604 connected with 10.19.200.240 port 5001
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [  5]  0.0-10.0 sec  1.12 GBytes   958 Mbits/sec
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [  4] local 10.27.204.71 port 5001 connected with 10.19.200.240 port 32771
    [paranoia-6-kavlan-16.rennes.grid5000.fr] [  4]  0.0-10.7 sec  2.25 MBytes  1.77 Mbits/sec


The variable `results` will be defined which contains the results for each test.
Let's print the results. Type the following into the `pry` console:

    results.each do |test, res|
      puts "Results of test: #{test}"
      res.each { |node,r| puts r[:stdout]}
    end

Which will give us:

    Results of test: bandwidth
    [ ID] Interval       Transfer     Bandwidth
    [  3]  0.0-10.0 sec  1.12 GBytes   958 Mbits/sec
    Results of test: bidi
    [  4]  0.0-10.0 sec  1.12 GBytes   957 Mbits/sec
    Results of test: window
    [ ID] Interval       Transfer     Bandwidth
    [  3]  0.0-10.7 sec  2.25 MBytes  1.77 Mbits/sec


Now let's look at the network traffic that we have generated during our experiment using KWAPI.
**Ruby-cute** offers the {Cute::G5K::API#get_metric get_metric} method to consult the G5K Metrology API.
In order to carry out a query and get the values of a specific probe,
we have to know the time interval of the values and the name of the probe.
Let's get the values for the metric `network_in`.
We could get all the names of the probes specific to this metric by typing:

    probes = $g5k.get_metric("rennes",:metric => "network_in").uids

Please replace the first parameter with the site you have used in the experiment.
If you type that in `pry` you will get:

    [13] pry(main)> probes
    => ["parasilo-11-eth0",
    "parasilo-11-eth1",
    "paravance-48-eth1",
    "paravance-48-eth0",
    "paravance-2-eth0",
    "paravance-2-eth1",
    "paranoia-4",
    "paranoia-5",
    "paranoia-6",
    "paranoia-7",
    "paravance-72-eth0",

In order to choose the right probes, we need to get the real names of the machines
and not the ones assigned by the VLAN. We can consult the job information:

    nodes_normal = []
    jobs.each{ |site,job| nodes_normal.push(job["assigned_nodes"])}

Which will give us an Array of Arrays that we can flatten by doing:

    [97] pry(main)> nodes_normal.flatten!
    => [["paranoia-6.rennes.grid5000.fr"], ["graphite-4.nancy.grid5000.fr"]]

As we are going to fetch the data for Rennes (First node). We could do:

    [68] pry(main)> probe_expe = probes.select{ |p| p == nodes_normal[0].split(".")[0] }

So, at this point we already have the probe we want to request.
Next step is to get the start time of the interval, we can choose for example, the time at which deployments have finished:

    deploy_end = []
    jobs.each{ |site,job| deploy_end.push(job["deploy"].last["updated_at"])}

Therefore, we could choose the maximum timestamp from the ones returned:

    start = deploy_end.max

Now, we can proceed by performing the query:

    $g5k.get_metric("rennes",:metric => "network_in",:query => {:from => start, :to => start+3600, :only => probe_expe.first})

An Array is returned. We can then open an editor and write a small script that will write these values into a file

    [33] pry(main)> edit -n get_results.rb

type:

    raw_data = $g5k.get_metric("rennes",:metric => "network_in",
                               :query => {:from => start, :to => start+3600, :only => probe_expe.first})

    network_in = raw_data.map{ |r| r["values"]}.flatten
    time  = raw_data.map{ |r| r["timestamps"]}.flatten

    values = Hash[time.zip(network_in)]

    File.open("network_in-values.txt",'w+') do |f|
      f.puts("time\t bytes")
      values.each{ |k,v| f.puts("#{k}\t#{v}")}
    end

and execute it with:

    pry(main)> play get_results.rb
    => {1453293153.732378=>4498405298908,
    1453293155.183099=>4498405298908,
    1453293156.582115=>4498405298908,
    1453293157.924968=>4498405298908,
    1453293159.28666=>4498405298908,
    1453293160.655534=>4498405298908,
    1453293161.998718=>4498405299219,

We can release the nodes:

    [58] pry(main)> jobs.values.each{ |j| $g5k.release(j)}

## Conclusions

This tutorial has shown how the scripting of complex experiment can be done using the Ruby scripting language.
We saw that in the context of Grid'5000,
**Ruby-Cute** offers useful methods for accessing the platform's services and executing commands in parallel.
The aim of this tutorial was to give you some ideas for coding your experiments using **Ruby-Cute**
and we hope it will be useful for your experiments.
