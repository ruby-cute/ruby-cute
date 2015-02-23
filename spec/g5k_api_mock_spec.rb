require 'spec_helper'

describe "Testing G5K::API class using mocking" do

  let(:subject) { Cute::G5K::API.new}
  # a compatible fake g5k media type for http responses.
  let(:g5k_media_type) {{'uid' => "1",
                      'items' => [{'uid' => "item1"},{'uid' => "item2"}],
                      'total' => [2],
                      'offset' => 2,
                      'links' => [{"rel" => "self","href" => "path", "type"=>"application/vnd.grid5000.collection+json"},
                                 {"rel" => "parent","href" => "path", "type"=>"application/vnd.grid5000.collection+json"}],
                      'state' => "running",
                      'status' => "terminated",
                      'assigned_nodes' => ["node1","node2"],
                      'resources_by_type' => {"res" => "val1"}
                        }}

  let(:job){ Cute::G5K::G5KJSON.parse(g5k_media_type.to_json) }

  before(:each) do

    data_test = Cute::G5K::G5KJSON.parse(g5k_media_type.to_json)
    Cute::G5K::G5KRest.any_instance.stub(:initialize).and_return(String)
    Cute::G5K::G5KRest.any_instance.stub(:get_json).and_return(data_test)
    Cute::G5K::G5KRest.any_instance.stub(:post_json).and_return(data_test)
    Cute::G5K::G5KRest.any_instance.stub(:folow_parent).and_return(data_test)
  end

  it "checks the initialization of G5K::API" do
    expect(subject.rest.class).to eq(Cute::G5K::G5KRest)
  end

  it "checks info methods" do
    expect(subject.site_uids.class).to eq(Array)
    expect(subject.cluster_uids("site").class).to eq(Array)
    expect(subject.environment_uids("site").class).to eq(Array)
    expect(subject.sites.class).to eq(Cute::G5K::G5KArray)
  end

  it "submits a job" do
    expect(subject.reserve(:site => "site")).to eq (g5k_media_type)
  end

  it "submits jobs with all options" do
    expect(subject.reserve(:site => "site", :cluster => "cluster", :switches => 2,
                           :nodes=>1, :cpus => 1, :cores => 1, :vlan => :routed, :type => :deploy,
                          :subnets => [])).to eq (g5k_media_type)
  end

  it "submits a job and does not wait" do
    expect(subject.reserve(:site => "site", :wait => false)).to eq (g5k_media_type)
  end

  it "It should raise argument errors" do
    expect {subject.deploy(:env => "env")}.to raise_error(ArgumentError)
    expect {subject.deploy(job)}.to raise_error(ArgumentError)
    expect {subject.reserve(:non_existing => "site")}.to raise_error(ArgumentError)
  end

  it "should deploy" do
    expect(subject.deploy(job,:env => "env").class).to eq (Cute::G5K::G5KJSON)
  end

  it "tests with all options" do
    fake_key = Tempfile.new(["keys",".pub"])
    fake_key_path = fake_key.path.split(".pub").first
    expect(subject.deploy(job,:env => "env",:wait => true, :keys => fake_key_path).class).to eq (Cute::G5K::G5KJSON)
    fake_key.delete
  end

  it "submits a job and then deploy" do
    expect(subject.reserve(:site => "site", :env => "env").class).to eq (Cute::G5K::G5KJSON)
  end

  it "submits a job and then deploy separately" do
    expect(subject.reserve(:site => "site", :type => :deploy ).class).to eq (Cute::G5K::G5KJSON)
    expect(subject.deploy(job,:env => "env", :wait => true ).class).to eq (Cute::G5K::G5KJSON)
  end


end
