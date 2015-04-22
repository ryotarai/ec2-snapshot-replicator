module EC2
  module Snapshot
    module Replicator
      class Config < Struct.new(:source_region, :destination_region, :interval_sec, :delay_deletion_sec, :owner_id, :debug)
        def load_options(options)
          self.source_region = options[:source_region]
          self.destination_region = options[:destination_region]
          self.interval_sec = options[:interval_sec]
          self.delay_deletion_sec = options[:delay_deletion_sec]
          self.owner_id = options[:owner_id]
          self.debug = options[:debug]
        end
      end
    end
  end
end

