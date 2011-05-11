require 'zip'

module Bindery
  module Extensions
    module ZipFileExtensions
      def write_file(entry, contents)
        get_output_stream(entry){|os| os.write(contents) }
      end
    end
  end
end

Zip::ZipFile.send(:include, Bindery::Extensions::ZipFileExtensions)
