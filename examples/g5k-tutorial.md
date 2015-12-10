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
    $ version: 3.0
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
To quit Cute namespace type:

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

Pry can be customized by creating the file `.pryrc`. We will create this
file with the following content in order to choose our prefered editor:

    $ cat > ~/.pryrc << EOF
    Pry.config.editor = "emacs"
    EOF

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

Now that we have found the sites, let's submit a job. You can use between Grenoble and Nancy sites. If you
take a look at {https://www.grid5000.fr/mediawiki/index.php/Status Monika} you will see that in Nancy we should use the OAR property 'ib20g' and in Grenoble we should use 'ib10g'.
Given that the MPI bench uses just one MPI process, we will need in realty just one core of a given machine.
We will use OAR syntax to ask for two cores in two different nodes with ib10g in Grenoble.

    [23] pry(main)> job = $g5k.reserve(:site => "grenoble", :resources => "{ib10g='YES'}/nodes=2/core=1",:walltime => '01:00:00', :keys => "~/my_ssh_jobkey" )
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
      ssh.exec!("export http_proxy=\"http://proxy:3128\"; wget -O ~/netpipe_exp/NetPIPE.tar.gz #{netpipe_url}")
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
We need to use `ssh.exec!` to capture the output of the commands.

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

## Running NAS benchmark in Grid'5000: getting acquainted with parallel command execution

In this experiment, we will run the NAS benchmark in Grid'5000. This experiment has the following requirements:

- 4 or 2 nodes from any Grid'5000 sites
- Use of production environment (no deploy)
- NAS MPI behchmark
- A MPI runtime (OpenMPI or MPICH)

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
The following example show how to use the {Cute::TakTuk TakTuk} module.

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

Which confirm the presence of both files on the nodes.
We can get the path of the binary by typing the following into `pry` console.

     Net::SSH::Multi.start do |session|
       nodes.each{ |node| session.use node }
       results = session.exec!("find /tmp/ -name lu.A.32")
     end

We will get some errors provoked by the `find` command:

     [32] pry(main)> results
     => {"genepi-27.grenoble.grid5000.fr"=>{:stdout=>"/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32", :stderr=>": Permission denied", :status=>1},
     "genepi-29.grenoble.grid5000.fr"=>{:stdout=>"/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32", :stderr=>": Permission denied", :status=>1},
     "genepi-19.grenoble.grid5000.fr"=>{:stderr=>": Permission denied", :stdout=>"/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32", :status=>1},
     "genepi-2.grenoble.grid5000.fr"=>{:stdout=>"/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32", :stderr=>": Permission denied", :status=>1}}


Then, we can assign this to a new variable:

     [33] pry(main)> lu_path = results.values.first[:stdout]
     => "/tmp/NPB3.3/NPB3.3-MPI/bin/lu.A.32"

The setup of the experiment is done. It is time to execute the benchmark by typing the following into `pry` console.

    Net::SSH.start(nodes.first,"cruizsanabria") do |ssh|
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

    Net::SSH.start(nodes.first,"cruizsanabria") do |ssh|
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
