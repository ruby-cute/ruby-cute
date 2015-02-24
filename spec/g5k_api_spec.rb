require 'spec_helper'

describe Cute::G5K::API do
  subject { Cute::G5K::API.new() }

  let(:sites) { subject.site_uids}
  let(:rand_site) { sites[rand(sites.length-1)]}

  before :each do
    # @p = Cute::G5K::API.new()
    # @sites = @p.site_uids
    # #Choosing a random site
    # @rand_site = @sites[rand(@sites.length-1)]
    puts "Warning G5K_USER environment variable has to be defined for some tests" if ENV['G5K_USER'].nil?
  end


  it "should return an array with the site ids" do
    expect(subject.site_uids.class).to eq(Array)
  end

  it "It should return an array with the clusters ids" do
    expect(subject.cluster_uids(rand_site).class).to eq(Array)
  end


  it "consults all the sites for their clusters" do
    clusters = subject.cluster_uids(rand_site)
    expect(clusters.length).to be > 0
  end

  it "should return a Json Hash with the status of a site" do
    expect(subject.site_status(rand_site).class).to eq(Cute::G5K::G5KJSON)
  end

  it "should return a Hash with nodes status" do
    expect(subject.nodes_status(rand_site).class).to eq(Hash)
    expect(subject.nodes_status(rand_site).length).to be > 1
  end

  it "should return an array with site status" do
    expect(subject.sites.class).to eq(Cute::G5K::G5KArray)
  end

  it "should not return any job" do
    expect(subject.get_my_jobs(rand_site).empty?).to eq(true)
  end

  it "should return the same information" do
    #low level REST access
    jobs_running = subject.rest.get_json("sid/sites/#{rand_site}/jobs/?state=running").items.length
    expect(subject.get_jobs(rand_site,nil,"running").length).to eq(jobs_running)
  end

  it "should submit a job with subnet reservation" do
    cluster = subject.cluster_uids(rand_site).first
    job = subject.reserve(:site => rand_site, :nodes => 1, :walltime => '00:10:00',
                          :subnets => [22,2], :cluster => cluster,:wait => false)
    job = subject.wait_for_job(job, :wait_time => 600)
    expect(job.class).to eq(Cute::G5K::G5KJSON)
    sleep 1
    # It verifies that the job has been submitted
    expect(subject.get_my_jobs(rand_site).empty? && subject.get_my_jobs(rand_site,"waiting").empty?).to eq(false)
    subnets = subject.get_subnets(job)
    expect(subnets.first.class).to eq(IPAddress::IPv4)
    expect(subnets.length).to eq(2)
  end

  it "should delete a job" do
    # Deleting the job
    subject.release_all(rand_site)
    sleep 20
    expect(subject.get_my_jobs(rand_site).empty? && subject.get_my_jobs(rand_site,"waiting").empty?).to eq(true)
  end

  it "should submit a job deploy" do
    environment = subject.environment_uids(rand_site).first
    job = subject.reserve(:site => rand_site,
                     :nodes => 1, :walltime => '00:40:00',
                     :env => environment)
    # It verifies that the job has been submitted with deploy
    expect(subject.get_my_jobs(rand_site).empty? && subject.get_my_jobs(rand_site,"waiting").empty?).to eq(false)
    expect(subject.get_my_jobs(rand_site).first["deploy"].empty?).to eq(false)
    expect(subject.deploy_status(job).class).to eq(Array)
    subject.wait_for_deploy(job)
    expect(subject.deploy_status(job)).to eq(["terminated"])

    #deploying again
    subject.deploy(job, :env => subject.environment_uids(rand_site)[3])
    subject.wait_for_deploy(job)
    expect(subject.deploy_status(job)).to eq(["terminated","terminated"])
  end

  it "should delete a job" do
    # Deleting the job
    subject.release_all(rand_site)
    sleep 20
    expect(subject.get_my_jobs(rand_site).empty? && subject.get_my_jobs(rand_site,"waiting").empty?).to eq(true)
  end

  it "should submit a job with OAR hierarchy" do
   job1 = subject.reserve(:site => rand_site, :switches => 2, :nodes=>1, :cpus => 1, :cores => 1,
                      :keys => "/home/#{ENV['G5K_USER']}/.ssh/id_rsa",:walltime => '00:10:00')
   job2 = subject.reserve(:site => rand_site, :resources => "/switch=2/nodes=1/cpu=1/core=1",
                     :keys => "/home/#{ENV['G5K_USER']}/.ssh/id_rsa",:walltime => '00:10:00')

   expect(subject.get_my_jobs(rand_site).length).to eq(2)

   subject.release_all(rand_site)
  end

end
