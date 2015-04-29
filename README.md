# ec2-snapshot-replicator

[![Circle CI](https://circleci.com/gh/ryotarai/ec2-snapshot-replicator.svg?style=svg)](https://circleci.com/gh/ryotarai/ec2-snapshot-replicator)

Replicate snapshots to another region with delayed deletion.

## Installation

    $ gem install ec2-snapshot-replicator

## Usage

```
$ ec2-snapshot-replicator start \
    --source-region=ap-northeast-1 \
    --destination-region=us-east-1 \
    --owner-id=123456789
```

### Options

- `--source-region`: region name where snapshots are replicated from (e.g. ap-northeast-1)
- `--destination-region`: region name where snapshots are replicated to (e.g. us-east-1)
- `--owner-id`: [account ID](http://docs.aws.amazon.com/general/latest/gr/acct-identifiers.html) of owner of snapshots
- `--once`: replicate once and exit (default: false)
- `--delay-deletion-sec`: if the source snapshot is deleted, the replicated one in the destination region will be deleted after `delay-deletion-sec`. (default: 604800 = 1 week)
- `--interval-sec`: interval seconds of loop (default: 600)
- `--config`: load configuration from YAML file (optional)

## What will be done?

```
$ ec2-snapshot-replicator start \
    --delay-deletion-sec=3600 \
    --interval-sec=600 \
    --source-region=ap-northeast-1 \
    --destination-region=us-east-1 \
    --owner-id=123456789
```

If the above settings are provided:

- loop the following:
  - If a snapshot in the source region is not found in the destination region, copy it to the destination region and create `SourceSnapshotId` tag.
  - If a snapshot in the destination region is not found in the source region, create `DeleteAfter` tag which is (now + 1 day) in seconds since unix epoch.
  - If `DeleteAfter` time of a snapshot in the destination region is over now, delete it.
  - Sleep 10 minutes

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/ryotarai/ec2-snapshot-replicator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
