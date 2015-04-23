require 'spec_helper'

Aws.config[:logger] = ::Logger.new($stdout)
Aws.config[:http_wire_trace] = true

module EC2::Snapshot::Replicator
  describe Engine do
    subject(:engine) { described_class.new(config) }
    let(:config) do
      Config.new.tap do |c|
        c.source_region = "ap-northeast-1"
        c.destination_region = "us-east-1"
        c.owner_id = "123456789"
        c.delay_deletion_sec = 3600
      end
    end

    let(:source_snapshot) { double(:snapshot, id: "snap-source1", description: 'desc') }
    let(:destination_snapshot) { double(:snapshot, id: 'snap-dest1', tags: [double(:tag, key: 'SourceSnapshotId', value: 'snap-source1')]) }

    describe "#replicate_snapshots" do
      context "when the source snapshot is not replicated" do
        it "copies the snapshot" do
          expect(engine.source_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id])
            .and_return([source_snapshot])

          expect(engine.destination_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id], filters: [{name: "tag:SourceSnapshotId", values: ["snap-source1"]}])
            .and_return([])

          expect(engine.destination_ec2).to receive(:snapshot)
            .with('snap-source1')
            .and_return(source_snapshot)

          expect(engine.destination_ec2).to receive(:snapshot)
            .with('snap-dest1')
            .and_return(destination_snapshot)

          expect(source_snapshot).to receive(:copy)
            .with(source_region: config.source_region, destination_region: config.destination_region, description: 'desc')
            .and_return(double(snapshot_id: destination_snapshot.id))

          expect(destination_snapshot).to receive(:create_tags)
            .with(tags: [{key: 'SourceSnapshotId', value: 'snap-source1'}])

          engine.replicate_snapshots
        end
      end

      context "when the source snapshot is already replicated" do
        it "doesn't copy the snapshot" do
          expect(engine.source_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id])
            .and_return([source_snapshot])

          expect(engine.destination_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id], filters: [{name: "tag:SourceSnapshotId", values: [source_snapshot.id]}])
            .and_return([destination_snapshot])

          expect(source_snapshot).not_to receive(:copy)

          engine.replicate_snapshots
        end
      end
    end

    describe "#mark_deleted_snapshots" do
      context "when the source snapshot is already deleted" do
        it "marks the destination snapshot 'will be deleted'" do
          expect(engine.destination_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id])
            .and_return([destination_snapshot])

          expect(engine.source_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id], filters: [{name: 'snapshot-id', values: ['snap-source1']}])
            .and_return([])

          expect(destination_snapshot).to receive(:create_tags)
            .with(tags: [{key: 'DeleteAfter', value: (Time.now + config.delay_deletion_sec).to_i.to_s}])

          engine.mark_deleted_snapshots
        end
      end

      context "when the source snapshot is not deleted" do
        it "doesn't mark the destination snapshot" do
          expect(engine.destination_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id])
            .and_return([destination_snapshot])

          expect(engine.source_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id], filters: [{name: 'snapshot-id', values: ['snap-source1']}])
            .and_return([source_snapshot])

          expect(destination_snapshot).not_to receive(:create_tags)

          engine.mark_deleted_snapshots
        end
      end
    end

    describe "#delete_snapshots" do
      context "when it is over DeleteAfter time" do
        let(:destination_snapshot) { double(:snapshot, id: 'snap-dest1', tags: [double(:tag, key: 'SourceSnapshotId', value: 'snap-source1'), double(:tag, key: 'DeleteAfter', value: (Time.now - 600).to_i.to_s)]) }

        it "deletes the snapshot" do
          expect(engine.destination_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id])
            .and_return([destination_snapshot])

          expect(destination_snapshot).to receive(:delete)

          engine.delete_snapshots
        end
      end

      context "when it is not over DeleteAfter time" do
        let(:destination_snapshot) { double(:snapshot, id: 'snap-dest1', tags: [double(:tag, key: 'SourceSnapshotId', value: 'snap-source1'), double(:tag, key: 'DeleteAfter', value: (Time.now + 600).to_i.to_s)]) }

        it "doesn't delete the snapshot" do
          expect(engine.destination_ec2).to receive(:snapshots)
            .with(owner_ids: [config.owner_id])
            .and_return([destination_snapshot])

          expect(destination_snapshot).not_to receive(:delete)

          engine.delete_snapshots
        end
      end
    end
  end
end

