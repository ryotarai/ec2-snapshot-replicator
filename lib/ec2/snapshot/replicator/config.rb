require 'yaml'

module EC2
  module Snapshot
    module Replicator
      class Config < Struct.new(:source_region, :destination_region, :interval_sec, :delay_deletion_sec, :owner_id, :debug, :access_key_id, :secret_access_key)
        def load_yaml_file(path)
          load_options(YAML.load_file(path))
        end

        def load_options(options)
          self.members.each do |member|
            self[member] = option[member] || option[member.to_s]
          end
        end
      end
    end
  end
end

