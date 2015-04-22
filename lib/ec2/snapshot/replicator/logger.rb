require 'logger'

module EC2
  module Snapshot
    module Replicator
      class Logger
        @logger = ::Logger.new($stdout)

        class << self
          %w!fatal error info debug trace!.each do |meth|
            meth = meth.to_sym
            define_method(meth) do |msg|
              @logger.public_send(meth, msg)
            end
          end
        end
      end
    end
  end
end

