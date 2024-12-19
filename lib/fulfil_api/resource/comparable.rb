# frozen_string_literal: true

module FulfilApi
  class Resource
    module Comparable
      def ==(other)
        other.is_a?(FulfilApi::Resource) &&
          other.hash == hash
      end

      def eql?(other)
        self == other
      end

      def hash
        @attributes.hash
      end
    end
  end
end
