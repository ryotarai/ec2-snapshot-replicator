require 'aws-sdk'

module EC2
  module Snapshot
    module Replicator
      class Engine
        SOURCE_SNAPSHOT_ID_TAG_KEY = 'SourceSnapshotId'
        DELETE_AFTER_TAG_KEY = 'DeleteAfter'

        attr_reader :source_ec2, :destination_ec2

        def initialize(config)
          @config = config

          @source_ec2 = Aws::EC2::Resource.new(region: @config.source_region)
          @destination_ec2 = Aws::EC2::Resource.new(region: @config.destination_region)
        end

        def start
          Logger.info "start loop"
          while true
            replicate_snapshots
            mark_deleted_snapshots
            delete_snapshots

            Logger.info "sleeping for #{@config.interval_sec} sec..."
            sleep @config.interval_sec
          end
        end

        private

        def replicate_snapshots
          Logger.info ">>> replicating snapshots..."
          @source_ec2.snapshots(owner_ids: [@config.owner_id]).each do |snapshot|
            unless @destination_ec2.snapshots(owner_ids: [@config.owner_id], filters: [{name: "tag:#{SOURCE_SNAPSHOT_ID_TAG_KEY}", values: [snapshot.id]}]).first
              Logger.info "[#{snapshot.id}] replicating..."

              ask_continue("Copy snapshot.")

              res = @destination_ec2.snapshot(snapshot.id).copy(
                source_region: @config.source_region,
                destination_region: @config.destination_region,
                description: snapshot.description,
              )

              Logger.debug "[#{res.snapshot_id}] created in #{@config.destination_region}"
              copied_snapshot = @destination_ec2.snapshot(res.snapshot_id)
              copied_snapshot.create_tags(
                tags: [
                  {key: SOURCE_SNAPSHOT_ID_TAG_KEY, value: snapshot.id},
                ],
              )
            else
              Logger.debug "[#{snapshot.id}] already replicated"
            end
          end
        end

        def mark_deleted_snapshots
          Logger.info ">>> marking deleted snapshots..."
          @destination_ec2.snapshots(owner_ids: [@config.owner_id]).each do |snapshot|
            if snapshot.tags.find {|t| t.key == DELETE_AFTER_TAG_KEY }
              next
            end

            Logger.debug "[#{snapshot.id}] checking deleted or not..."
            tag = snapshot.tags.find {|t| t.key == SOURCE_SNAPSHOT_ID_TAG_KEY }
            unless tag
              Logger.debug "[#{snapshot.id}] tag #{SOURCE_SNAPSHOT_ID_TAG_KEY} is not found."
              next
            end

            unless @source_ec2.snapshots(owner_ids: [@config.owner_id], filters: [{name: 'snapshot-id', values: [tag.value]}]).first
              Logger.info "[#{snapshot.id}] creating #{DELETE_AFTER_TAG_KEY} tag because source snapshot (#{tag.value}) is deleted."

              delete_after = (Time.now + @config.delay_deletion_sec).to_i
              ask_continue("Create a tag #{DELETE_AFTER_TAG_KEY}:#{delete_after}.")
              snapshot.create_tags(
                tags: [
                  {key: DELETE_AFTER_TAG_KEY, value: delete_after.to_s},
                ],
              )
            end
          end
        end

        def delete_snapshots
          Logger.info ">>> deleting snapshots..."
          @destination_ec2.snapshots(owner_ids: [@config.owner_id]).each do |snapshot|
            tag = snapshot.tags.find {|t| t.key == DELETE_AFTER_TAG_KEY }

            unless tag
              Logger.debug "[#{snapshot.id}] tag #{DELETE_AFTER_TAG_KEY} is not found."
              next
            end

            delete_after = Time.at(tag.value.to_i)
            if delete_after < Time.now
              Logger.info "[#{snapshot.id}] deleting..."
              ask_continue("Delete #{snapshot.id}.")
              snapshot.delete
            end
          end
        end

        def ask_continue(msg)
          return unless @config.debug

          print "#{msg} continue? (y/N): "
          unless $stdin.gets.downcase =~ /\Ay/
            abort
          end
        end
      end
    end
  end
end

