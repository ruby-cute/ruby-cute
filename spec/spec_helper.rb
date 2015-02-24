require 'cute'

RSpec.configure do |config|
  config.fail_fast = true
  config.files_to_run = ["g5k_api_mock_spec.rb","g5k_api_spec.rb"]
  config.mock_with :rspec do |c|
    c.syntax = [:expect,:should]
  end

end
