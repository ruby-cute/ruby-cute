require 'spec_helper'

#These tests will check the API Grid'5000 using all the methods that perform a GET request

describe Cute::G5K::API do

  subject { g5k = ENV['TEST_REAL'].nil?? Cute::G5K::API.new(:user => "test") : Cute::G5K::API.new() }

  before :each do
    if ENV['TEST_REAL']
      WebMock.disable!
    end
  end

  it "checks initialization of G5K::API" do
    expect(subject.rest).to be_an_instance_of(Cute::G5K::G5KRest)
  end

  it "returns an array with the clusters ids in nancy" do
    clusters = subject.cluster_uids("nancy")
    expect(clusters.length).to be > 0
  end

  it "returns an array with the clusters ids in grenoble" do
    clusters = subject.cluster_uids("grenoble")
    expect(clusters.length).to be > 0
  end

  it "returns an array with the clusters ids in lyon" do
    clusters = subject.cluster_uids("lyon")
    expect(clusters.length).to be > 0
  end

  it "returns an array with the clusters ids in lille" do
    clusters = subject.cluster_uids("lille")
    expect(clusters.length).to be > 0
  end

  it "returns a JSON Hash with the status of a site grenoble" do
    expect(subject.site_status("grenoble")).to be_an_instance_of(Cute::G5K::G5KJSON)
  end

  it "returns a JSON Hash with the status of a site nancy" do
    expect(subject.site_status("nancy")).to be_an_instance_of(Cute::G5K::G5KJSON)
  end

  it "return my_jobs in lille site" do
    expect(subject.get_my_jobs("lille")).to be_an_instance_of(Array)
  end

  it "returns all deployments in nancy" do
    expect(subject.get_deployments("nancy")).to be_an_instance_of(Cute::G5K::G5KArray)
  end

  it "returns all deployments in lille" do
    expect(subject.get_deployments("lille")).to be_an_instance_of(Cute::G5K::G5KArray)
  end

  it "returns all deployments in grenoble" do
    expect(subject.get_deployments("grenoble")).to be_an_instance_of(Cute::G5K::G5KArray)
  end

end
