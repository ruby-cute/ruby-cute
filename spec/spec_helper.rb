require 'simplecov'
require 'webmock/rspec'

SimpleCov.start
# The SimpleCov.start must be issued before any of the application code is required!
# SimpleCov hacks $:, so it needs to be re-configured here, before cute is loaded.
$:.unshift File.expand_path("../../lib", __FILE__)
require 'cute'

# Disabling all external requests
WebMock.disable_net_connect!(allow_localhost: true)


class FakeG5KResponse < Hash
  MEDIA_TYPE = {'uid' => "1",
                'id' => "1",
                'user' => "test",
                'items' => [{'uid' => "item1"},{'uid' => "item2"}],
                'total' => [2],
                'offset' => 2,
                'links' => [{"rel" => "self","href" => "path", "type"=>"application/vnd.grid5000.collection+json"},
                            {"rel" => "parent","href" => "path", "type"=>"application/vnd.grid5000.collection+json"}],
                'state' => "running",
                'started_at' => Time.now,
                'created_at' => Time.now,
                'status' => "terminated",
                'types' => ["deploy"],
                'assigned_nodes' => ["node1","node2"],
                'resources_by_type' => {"res" => "val1","subnets" => ["10.140.0.0/22"], "vlans"=>["4"]},
                'nodes' => {"node1" => {"hard"=> "alive", "soft"=>"busy"}}
               }
  def initialize(num_items = 2)
    MEDIA_TYPE.each { |key,value| self[key] = value}
    self['items'] = []
    num_items.times.each{ self['items'].push(MEDIA_TYPE) }
  end

end


RSpec.configure do |config|
  config.fail_fast = true

  g5k_media_type = FakeG5KResponse.new
  # Example using addressable templates
  # uri_sites = Addressable::Template.new "https://{user}:{password}@api.grid5000.fr/{version}/sites"
  config.before(:each) do

    stub_request(:any,/^https:\/\/.*\:.*@api.grid5000.fr\/.*/).
      to_return(:status => 200, :body => g5k_media_type.to_json, :headers => {})

    stub_request(:any,/^https:\/\/fake:fake@api.grid5000.fr\.*/).
      to_return(:status => 401)

    stub_request(:any,/^https:\/\/.*\:.*@api.grid5000.fr\/...\/sites\/non-found\/.*/).
      to_return(:status => 404)

    stub_request(:any,/^https:\/\/.*\:.*@api.grid5000.fr\/...\/sites\/tmpfail\/.*/).
      to_return(:status => 503).
      to_return(:status => 200, :body => g5k_media_type.to_json, :headers => {})

    stub_request(:get,/^https:\/\/.*\:.*@api.grid5000.fr\/...\/sites\/.*vlans$/).
      to_return(:status => 200, :body => {'total' => 3, 'items' => [{'type' => "kavlan-local"},{'type' => "kvlan"}]}.to_json)

      # to_return(:status => 200, :body => {:total => 3, :items => [{:type => "kavlan-local"},{:type => "kavlan"}]})

    stub_request(:post, /^https:\/\/.*\:.*@api.grid5000.fr\/.*/).
      with(:body => hash_including("resources" => "/slash_22=1+{nonsense},walltime=01:00")).
      to_return(:status => 400, :body => "Oarsub failed: please verify your request syntax")

    stub_request(:post, /^https:\/\/.*\:.*@api.grid5000.fr\/.*/).
      with(:body => hash_including("import-job-key-from-file" => [ File.expand_path("~/jobkey_nonexisting") ])).
      to_return(:status => 400, :body => "Oarsub failed: please verify your request syntax")

    stub_request(:post, /^https:\/\/.*\:.*@api.grid5000.fr\/.*/).
      with(:body => hash_including("environment" => "nonsense")).
      to_return(:status => 500, :body => "Invalid environment specification")

  end

end
