require 'thor'

module EC2
  module Snapshot
    module Replicator
      class CLI < Thor
        desc "version", "Show version"
        def version
          puts "v#{EC2::Snapshot::Replicator::VERSION}"
        end
      end
    end
  end
end
