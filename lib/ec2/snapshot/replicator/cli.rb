require 'thor'

module EC2
  module Snapshot
    module Replicator
      class CLI < Thor
        desc "version", "Show version"
        def version
          puts "v#{EC2::Snapshot::Replicator::VERSION}"
        end

        desc "start", "Start"
        method_option :source_region, type: :string, required: true
        method_option :destination_region, type: :string, required: true
        method_option :interval_sec, type: :numeric, default: 60 * 10
        method_option :delay_deletion_sec, type: :numeric, default: 60 * 60 * 24 * 7
        def start
          config = Config.new
          config.load_options(options)

          Engine.new(config).start
        end
      end
    end
  end
end
