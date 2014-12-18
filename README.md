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

*username* and *password* are not neccesary if you are using the module from inside Grid'5000.

You can specify another file using the option :conf_file, for example:

    g5k = Cute::G5KAPI.new({:conf_file => "config file path"})

Or you can specify other parameter to use:

    g5k = Cute::G5KAPI.new({:uri =>"https://api.grid5000.fr"})

## Examples
### Reserving a node in a given site.
The following script will reserve a node in Nancy for 10 minutes.

    require 'cute'

    g5k = Cute::G5KAPI.new()
    job = g5k.reserve(:nodes => 1, :site => 'nancy', :walltime => '00:10:00')

### Deploying an environment.
This script will reserve and deploy the *wheezy-x64-base* environment.
Your public ssh key located in *~/.ssh* will be copied by default to the deployed machines,
you can specify another path for your key with the option *:public_key*.

    require 'cute'

    g5k = Cute::G5KAPI.new()

    job = g5k.reserve(:nodes => 1, :site => 'grenoble',
                            :walltime => '00:40:00',
                            :env => 'wheezy-x64-base')


### Complex reservation

The method {Cute::G5KAPI#reserve reserve} support several parameters to perform more complex reservations.
The script below reserves 2 nodes in the cluster *chirloute* located in Lille for 1 hour as well as 2 /22 subnets.
2048 ip addresses will be available that can be used, for example, in virtual machines.

    require 'cute'

    g5k = Cute::G5KAPI.new()

    job = g5k.reserve(:site => 'lille', :cluster => 'chirloute', :nodes => 2,
                            :time => '01:00:00', :env => 'wheezy-x64-xen',
                            :public_key => 'http://public.grenoble.grid5000.fr/~user/id_rsa.pub',
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


Other examples with properties:

    job = g5k.reserve(:site => 'lyon', :nodes => 2, :properties => "wattmeter='YES'")

    job = g5k.reserve(:site => 'nancy', :nodes => 1, :properties => "switch='sgraphene1'")

    job = g5k.reserve(:site => 'nancy', :nodes => 1, :properties => "cputype='Intel Xeon E5-2650'")

Using OAR hierarchy:

    job = g5k.reserve(:site => "grenoble", :switches => 3, :nodes=>1, :cpus => 1, :cores => 1)

The previous reservation can be done as well using the OAR syntax:

    job = g5k.reserve(:site => "grenoble", :resources => "/switch=3/nodes=1/cpu=1/core=1")

This syntax allow to express more complex reservations. For example, combining OAR hierarchy with properties:

    job = g5k.reserve(:site => "grenoble", :resources => "{ib10g='YES' and memnode=24160}/cluster=1/nodes=2/core=1")

if we want 2 nodes with the following constraints:
1) nodes on 2 different clusters of the same site, 2) nodes with virtualization capability enabled
3) 1 /22 subnet. The reservation will be like:

    job = g5k.reserve(:site => "rennes", :resources => "/slash_22=1+{virtual!='none'}/cluster=2/nodes=1")

Another reservation for two clusters:

    job = g5k.reserve(:site => "nancy", :resources => "{cluster='graphene'}/nodes=2+{cluster='griffon'}/nodes=3")


## Contact information

Ruby-Cute is maintained by the Algorille team at LORIA/Inria Nancy - Grand Est, and specifically by:

* Sébastien Badia <sebastien.badia@inria.fr>
* Tomasz Buchert <tomasz.buchert@inria.fr>
* Emmanuel Jeanvoine <emmanuel.jeanvoine@inria.fr>
* Lucas Nussbaum <lucas.nussbaum@loria.fr>
* Luc Sarzyniec <luc.sarzyniec@inria.fr>
* Cristian Ruiz <cristian.ruiz@inria.fr>

Questions/comments should be directed to Lucas Nussbaum and Emmanuel Jeanvoine.
