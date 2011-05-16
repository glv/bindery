require 'zip'

module Bindery
  module Extensions
    module ZipFileExtensions
      def write_file(entry, contents)
        get_output_stream(entry){|os| os.write(contents) }
      end
      
      def write_uncompressed_file(entry_name, contents)
        entry = Zip::ZipEntry.new(@name, entry_name.to_s)
        entry.compression_method = Zip::ZipEntry::STORED
        write_file(entry, contents)
      end
    end
    
    module ZipStreamableStreamExtensions
      def kind_of?(thing)
        # ZipStreamableStream is a ZipEntry, but through delegation, not inheritance.
        return true if thing == ::Zip::ZipEntry
        super
      end
    end
  end
end

Zip::ZipFile.send(:include, Bindery::Extensions::ZipFileExtensions)
Zip::ZipStreamableStream.send(:include, Bindery::Extensions::ZipStreamableStreamExtensions)
