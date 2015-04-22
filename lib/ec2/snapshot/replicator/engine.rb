require 'aws-sdk'

module EC2
  module Snapshot
    module Replicator
      class Engine
        def initialize(config)
          @config = config

          @source_ec2 = Aws::EC2::Resource.new(region: @config.source_region)
          @destination_ec2 = Aws::EC2::Resource.new(region: @config.destination_region)
        end

        def start
          while
            replicate_snapshots
            mark_deleted_snapshots
            delete_snapshots
            sleep @config.interval_sec
          end
        end

        private

        def replicate_snapshots
          @source_ec2.snapshots.each do |snapshot|
            if @destination_ec2.snapshots(filters: [{name: "tag:SourceSnapshotId", values: [snapshot.id]}]).empty?
              res = snapshot.copy(
                source_region: @config.source_region,
                destination_region: @config.destination_region,
              )

              copied_snapshot = @destination_ec2.snapshot(res.snapshot_id)
              copied_snapshot.create_tags(
                tags: [
                  {key: 'SourceSnapshotId', value: snapshot.id},
                ],
              )
            end
          end
        end

        def mark_deleted_snapshots
          @destination_ec2.snapshots.each do |snapshot|
            tag = snapshot.tags.find {|t| t.key == 'SourceSnapshotId' }
            next unless tag

            unless @source_ec2.snapshot(tag.value)
              snapshot.create_tags(
                tags: [
                  {key: 'DeleteAfter', value: (Time.now + @config.delay_deletion_sec).to_i.to_s},
                ],
              )
            end
          end
        end

        def delete_snapshots
          @destination_ec2.snapshots.select do |snapshot|
            tag = snapshot.tags.find {|t| t.key == 'DeleteAfter' }

            next unless tag

            delete_after = Time.at(tag.value.to_i)
            if delete_after < Time.now
              snapshot.delete
            end
          end
        end
      end
    end
  end
end

