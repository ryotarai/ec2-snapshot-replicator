$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'ec2/snapshot/replicator'

config = {}
config[:stub_responses] = true
if ENV['DEBUG']
  config[:logger] = ::Logger.new($stdout)
  config[:http_wire_trace] = true
end

Aws.config = config

module Aws
  module ClientStubs
    class NoStubFoundError < StandardError; end

    # https://github.com/aws/aws-sdk-ruby/blob/bcfc785af4af60c6e1639dee052553cc06b3106a/aws-sdk-core/lib/aws-sdk-core/client_stubs.rb#L93
    def next_stub(operation_name)
      @stub_mutex.synchronize do
        stubs = @stubs[operation_name.to_sym] || []
        case stubs.length
        when 0
          raise NoStubFoundError, "No stub for #{operation_name} is not registered."
        when 1 then stubs.first
        else stubs.shift
        end
      end
    end
  end
end

