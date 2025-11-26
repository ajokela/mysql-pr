# frozen_string_literal: true

require "mysql-pr"

# Track all MySQL connections for cleanup
module MysqlConnectionTracker
  @connections = []
  @mutex = Mutex.new

  class << self
    def track(conn)
      @mutex.synchronize { @connections << conn }
      conn
    end

    def close_all
      @mutex.synchronize do
        @connections.each do |conn|
          conn&.close
        rescue StandardError
          nil
        end
        @connections.clear
      end
    end

    def connection_count
      @mutex.synchronize { @connections.size }
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.warnings = true

  config.order = :random
  Kernel.srand config.seed

  # Force close all connections after each example group
  config.after(:context) do
    MysqlConnectionTracker.close_all
  end

  # Final cleanup after all tests
  config.after(:suite) do
    MysqlConnectionTracker.close_all
  end
end
