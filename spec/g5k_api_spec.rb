require 'spec_helper'

describe Cute::G5KUser do

  before do
    credentials = YAML.load(File.open("#{ENV['HOME']}/.grid5000_api.yml",'r'))
    @p = Cute::G5KUser.new(credentials["uri"],credentials["username"],credentials["password"])
    #low level REST access
    @k = Cute::G5KRest.new(credentials["uri"],credentials["username"],credentials["password"])
    @sites = @p.site_uids
  end

  it "It should return an array with the site ids" do
    expect(@p.site_uids.class).to eq(Array)
  end

  it "It should return an array with the clusters ids" do
    expect(@p.cluster_uids(@sites.first).class).to eq(Array)
  end

  it "It consults all the site for their clusters" do
    @sites.each{ |site_name|
      expect(@p.cluster_uids(site_name).length).to be > 0
    }
  end

  it "It should return a Json Hash with the status of a site" do
    expect(@p.site_status(@sites.first).class).to eq(Cute::G5KJson)
  end

  it "It should return a Hash with nodes status" do
    expect(@p.get_nodes_status(@sites.first).class).to eq(Hash)
    #choosing a random site
    rand_site = @sites[rand(@sites.length-1)]
    expect(@p.get_nodes_status(rand_site).length).to be > 1
  end

  it "It should return an array with site status" do
    expect(@p.sites.class).to eq(Cute::G5KArray)
  end

  it "it should not return any job" do
    expect(@p.my_jobs(@sites.first).empty?).to eq(true)
  end

  it "it should return the same information" do
    rand_site = @sites[rand(@sites.length-1)]
    jobs_running = @k.get_json("sid/sites/#{rand_site}/jobs/?state=running").items.length
    expect(@p.get_jobs(rand_site,"running").length).to eq(jobs_running)
  end

  it "it should submit a job" do
    #choosing a random site
    rand_site = @sites[rand(@sites.length-1)]
    expect(@p.reserve_nodes(:site => rand_site, :nodes => 1, :time => '00:10:00').class).to eq(Cute::G5KJson)
    sleep 1
    # verifies that the job has been submitted
    expect( @p.my_jobs(rand_site).empty? || @p.my_jobs(rand_site,"waiting").empty?).to eq(true)
    # Deleting the job
    @p.release_all(rand_site)
    sleep 2
    expect( @p.my_jobs(rand_site).empty? && @p.my_jobs(rand_site,"waiting").empty?).to eq(false)
  end

end
