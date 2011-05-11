module Bindery
  module Extensions
    module StringExtensions
      # stolen from Scala
      def strip_margin
        gsub(/^\s*\|/m, '')
      end
    end
  end
end

String.send(:include, Bindery::Extensions::StringExtensions)
