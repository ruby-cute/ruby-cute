require 'spec_helper'

describe Cute::G5KAPI do

  before :all do
    config_file = "#{ENV['HOME']}/.grid5000_api.yml"
    config = {}
    @p = File.exists?(config_file) ? Cute::G5KAPI.new({:conf_file => config_file}) : Cute::G5KAPI.new({:uri =>"https://api.grid5000.fr"})
    @sites = @p.site_uids
    #Choosing a random site
    @rand_site = @sites[rand(@sites.length-1)]
  end

  it "It should return an array with the site ids" do
    expect(@p.site_uids.class).to eq(Array)
  end

  it "It should return an array with the clusters ids" do
    expect(@p.cluster_uids(@sites.first).class).to eq(Array)
  end


  it "It consults all the sites for their clusters" do
    clusters = @p.cluster_uids(@rand_site)
    expect(clusters.length).to be > 0
  end

  it "It should return a Json Hash with the status of a site" do
    expect(@p.site_status(@sites.first).class).to eq(Cute::G5KJson)
  end

  it "It should return a Hash with nodes status" do
    expect(@p.nodes_status(@sites.first).class).to eq(Hash)
    expect(@p.nodes_status(@rand_site).length).to be > 1
  end

  it "It should return an array with site status" do
    expect(@p.sites.class).to eq(Cute::G5KArray)
  end

  it "it should not return any job" do
    expect(@p.my_jobs(@sites.first).empty?).to eq(true)
  end

  it "it should return the same information" do
    #low level REST access
    jobs_running = @p.rest.get_json("sid/sites/#{@rand_site}/jobs/?state=running").items.length
    expect(@p.get_jobs(@rand_site,"running").length).to eq(jobs_running)
  end

  it "it should submit a job" do
    cluster = @p.cluster_uids(@rand_site).first
    expect(@p.reserve_nodes(:site => @rand_site,
                      :nodes => 1, :time => '00:10:00',
                      :subnets => [22,2], :cluster => cluster).class).to eq(Hash)
    sleep 1
    # It verifies that the job has been submitted
    expect(@p.my_jobs(@rand_site).empty? && @p.my_jobs(@rand_site,"waiting").empty?).to eq(false)
  end

  it "it should return job subnets" do
    subnets = @p.get_subnets(@rand_site)
    expect(subnets.first.class).to eq(IPAddress::IPv4)
    expect(subnets.length).to eq(2)
  end

  it "it should delete a job" do
    # Deleting the job
    @p.release_all(@rand_site)
    sleep 3
    expect(@p.my_jobs(@rand_site).empty? && @p.my_jobs(@rand_site,"waiting").empty?).to eq(true)
  end

  it "it should submit a job deploy" do
    environment = @p.environment_uids(@rand_site).first
    ref = @p.reserve_nodes(:site => @rand_site,
                     :nodes => 1, :time => '00:40:00',
                     :env => environment)
    # It verifies that the job has been submitted
    expect(@p.my_jobs(@rand_site).empty? && @p.my_jobs(@rand_site,"waiting").empty?).to eq(false)
    expect(@p.deploy_status(ref[:deploy])["status"].class).to eq(String)
  end

  it "it should delete a job" do
    # Deleting the job
    @p.release_all(@rand_site)
    sleep 3
    expect(@p.my_jobs(@rand_site).empty? && @p.my_jobs(@rand_site,"waiting").empty?).to eq(true)
  end

end
