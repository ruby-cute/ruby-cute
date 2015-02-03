require 'grid5000/subnets'
require 'bundler'
Bundler.setup  # Use this when working in development mode.
require 'cute'
require 'net/scp'


# This script implements the example Virtualization on Grid'5000 and subnet reservation in Grid'5000.
# In a nutshell, a machine and a sub network is reserved per site.
# Configuration files are generated to make kvm vms take the IPs addresses reserved, then several virtual
# machines are booted per machine (default 2). At the end all virtual machines are contacted vis SSH.
# The example is described in https://www.grid5000.fr/mediawiki/index.php/Virtualization_on_Grid%275000

g5k = Cute::G5KAPI.new()
# We reuse a job if there is one available.
G5K_SITES = [:lille, :rennes, :lyon, :grenoble]

threads = []
jobs = {}
grid5000_opt = {:user => "oar", :keys => ["~/.ssh/id_rsa"], :port => 6667 }
num_vm = 2 # Number of vms per site

G5K_SITES.each{ |site|
  threads << Thread.new {
    if g5k.get_my_jobs(site).empty?
      jobs[site] = g5k.reserve(:site => site, :resources => "slash_22=1+{virtual!='none'}/nodes=1", :walltime =>"01:00:00",:keys => "~/.ssh/id_rsa" )
    else
      jobs[site] = g5k.get_my_jobs(site).first
    end
  }
}

threads.each{ |t| t.join}

nodes = []
jobs.each{ |k,v| nodes+=v["assigned_nodes"]}

puts("Nodes reserved: #{nodes.inspect}")

# Creating vm configuration files
vm_dir = Dir.mktmpdir("vm_def")

system("wget -O #{vm_dir}/vm-template.xml http://public.nancy.grid5000.fr/~cruizsanabria/vm-template.xml")

template = ERB.new(File.read("#{vm_dir}/vm-template.xml"))

vms = []

G5K_SITES.each{ |site|
  subnet  = g5k.get_subnets(site).first
  ips = subnet.map{ |ip| ip.to_s }
  num_vm.times{ |n|
    @vm_name = "node#{n}.#{site}"
    @vm_mac = ip2mac(ips[n+1])
    vms.push(ips[n+1]) # avoiding .0 last octet
    @tap_device = "tap#{n}"
    File.open("#{vm_dir}/node_#{n}.#{site}.xml",'w+') do |f|
      f.puts(template.result()) # ERB replaces @vm_name, @vm_mac and, @tap_device in the file.
    end
  }
}

puts("vm's ip assigned #{vms.inspect}")

# Setting up VMs
Cute::TakTuk.start(nodes, grid5000_opt) do |tak|

  tak.exec!("mkdir -p ~/vm_definitions")
  #Taktuk put doest work with big files
  # tak.put("/home/cruizsanabria/wheezy-x64-base.qcow2","/tmp/wheezy-x64-base.qcow2")
  tak.exec("wget -q -O /tmp/wheezy-x64-base.qcow2 http://public.nancy.grid5000.fr/~cruizsanabria/wheezy-x64-base.qcow2")
  puts("Transfering configuration files")
  Dir.entries(vm_dir).each{ |vm_file|
    next if vm_file[0] =="." # avoid . and .. files
    puts File.join(vm_dir,vm_file)
    tak.put(File.join(vm_dir,vm_file),"/tmp/#{vm_file}")
  }
  # Creates a number of tap devices number of vms/number of machines
  puts("Creating TAP devices")
  num_vm.times{ tak.exec!("sudo create_tap") }

  # Creating contextualization script to copy our ssh key
  tak.exec!("mkdir -p ~/kvm-context")
  tak.exec!("cp ~/.ssh/id_rsa.pub ~/kvm-context/")
  File.open("/tmp/post-install","w+") do |f|
    f.puts("#!/bin/sh")
    f.puts("mkdir -p /root/.ssh")
    f.puts("cat /mnt/id_rsa.pub >> /root/.ssh/authorized_keys")
  end
  tak.put("/tmp/post-install","/tmp/post-install")
  tak.exec!("cp /tmp/post-install ~/kvm-context/post-install")
  tak.exec!("chmod 755 ~/kvm_context/post-install")
  tak.exec!("genisoimage -r -o /tmp/kvm-context.iso ~/kvm-context/")
end

# Starting vms
Net::SSH::Multi.start do |session|
  jobs.each{ |site,job|
    # We create a group per site
    session.group site do
      job["assigned_nodes"].each{ |node|
        session.use node, grid5000_opt
      }
    end
    num_vm.times{ |n| puts session.with(site).exec!("virsh create /tmp/node_#{n}.#{site}.xml")}
  }
end

puts("Waiting for the machines to start")
sleep 60
# Executing some commands on the vms

Net::SSH::Multi.start do |session|

  vms.each{ |vm|
    session.use("root@#{vm}")
  }
  session.exec("hostname")
  session.exec("uptime")

end
