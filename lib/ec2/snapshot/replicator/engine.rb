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

          set_credentials

          @source_ec2 = Aws::EC2::Resource.new(region: @config.source_region)
          @destination_ec2 = Aws::EC2::Resource.new(region: @config.destination_region)
        end

        def start
          Logger.info "start loop"
          while true
            run_once

            Logger.info "sleeping for #{@config.interval_sec} sec..."
            sleep @config.interval_sec
          end
        end

        def run_once
          replicate_snapshots
          mark_deleted_snapshots
          delete_snapshots
        end

        def replicate_snapshots
          Logger.info ">>> replicating snapshots..."

          source_snapshots = @source_ec2.snapshots(owner_ids: [@config.owner_id])
          source_snapshot_ids = source_snapshots.map {|s| s.id }

          destination_snapshots = @destination_ec2.snapshots(owner_ids: [@config.owner_id], filters: [{name: "tag:#{SOURCE_SNAPSHOT_ID_TAG_KEY}", values: source_snapshot_ids}])
          source_snapshots.each do |snapshot|
            destination_snapshot = destination_snapshots.find do |s|
              s.tags.find do |t|
                t.key == SOURCE_SNAPSHOT_ID_TAG_KEY &&
                  t.value == snapshot.id
              end
            end

            if destination_snapshot
              Logger.debug "[#{snapshot.id}] already replicated"
            else
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
            end
          end
        end

        def mark_deleted_snapshots
          Logger.info ">>> marking deleted snapshots..."

          destination_snapshots = @destination_ec2.snapshots(owner_ids: [@config.owner_id]).select do |snapshot|
            if snapshot.tags.find {|t| t.key == DELETE_AFTER_TAG_KEY }
              next false
            end

            unless snapshot.tags.find {|t| t.key == SOURCE_SNAPSHOT_ID_TAG_KEY }
              Logger.debug "[#{snapshot.id}] tag #{SOURCE_SNAPSHOT_ID_TAG_KEY} is not found."
              next false
            end

            true
          end

          source_snapshot_ids = destination_snapshots.map do |snapshot|
            snapshot.tags.find {|t| t.key == SOURCE_SNAPSHOT_ID_TAG_KEY }.value
          end

          source_snapshots = @source_ec2.snapshots(owner_ids: [@config.owner_id], filters: [{name: 'snapshot-id', values: source_snapshot_ids}])

          destination_snapshots.each do |snapshot|
            source_snapshot_id = snapshot.tags.find {|t| t.key == SOURCE_SNAPSHOT_ID_TAG_KEY }.value
            if source_snapshots.find {|s| s.id == source_snapshot_id }
              Logger.debug "[#{snapshot.id}] source snapshot (#{source_snapshot_id}) exists"
            else
              Logger.info "[#{snapshot.id}] creating #{DELETE_AFTER_TAG_KEY} tag because source snapshot (#{source_snapshot_id}) is deleted."

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

        private

        def ask_continue(msg)
          return unless @config.debug

          print "#{msg} continue? (y/N): "
          unless $stdin.gets.downcase =~ /\Ay/
            abort
          end
        end

        def set_credentials
          if @config.access_key_id && @config.secret_access_key
            Aws.config.update({
              credentials: Aws::Credentials.new(
                @config.access_key_id,
                @config.secret_access_key,
              ),
            })
          end
        end
      end
    end
  end
end

