require "ec2/snapshot/replicator"
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
        method_option :owner_id, type: :string, required: true
        method_option :debug, type: :boolean, default: false
        method_option :once, type: :boolean, default: false
        method_option :config, type: :string
        def start
          config = Config.new

          config.load_options(options)
          if options[:config]
            config.load_yaml_file(options[:config])
          end

          if options[:once]
            Engine.new(config).run_once
          else
            Engine.new(config).start
          end
        end
      end
    end
  end
end
