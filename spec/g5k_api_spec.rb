require 'spec_helper'

describe Cute::G5KUser do

  before do
    credentials = YAML.load(File.open("#{ENV['HOME']}/.grid5000_api.yml",'r'))
    @p = Cute::G5KUser.new(credentials["uri"],credentials["username"],credentials["password"])
    @site = @p.site_uids.first
  end

  it "It should return an array with the site ids" do
    expect(@p.site_uids.class).to eq(Array)
  end

  it "It should return an array with the clusters ids" do
    expect(@p.cluster_uids(@site).class).to eq(Array)
  end

  it "It should return a Json Hash with the status of a site" do
    expect(@p.site_status(@site).class).to eq(Cute::G5KJson)
  end

  it "It should return a Hash with nodes status" do
    expect(@p.get_nodes_status(@site).class).to eq(Hash)
    expect(@p.get_nodes_status(@site).length).to be > 1
  end

  it "It should return an array with site status" do
    expect(@p.sites.class).to eq(Cute::G5KArray)
  end

end
