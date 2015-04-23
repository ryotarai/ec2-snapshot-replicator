require 'spec_helper'

describe EC2::Snapshot::Replicator do
  it 'has a version number' do
    expect(EC2::Snapshot::Replicator::VERSION).not_to be nil
  end
end
