module Bindery
  class Book
    class Metadata < Struct.new(:name, :value, :options)
    end
    
    class DublinMetadata < Metadata
    end
    
    attr_accessor :output, :url, :isbn, :title, :language, :author, :subtitle
    
    def metadata
      @metadata ||= []
    end
    
    def formats
      @formats ||= []
    end
    
    def divisions
      @divisions ||= []
    end
    
    def full_title
      title + (subtitle ? ": #{subtitle}" : '')
    end
    
    def valid?
      configuration_valid? && metadata_valid? && divisions_valid?
    end
    
    def configuration_valid?
      true
      # formats specified or correctly defaulted
      # ouput specified
      # at least one division
    end
    
    def metadata_valid?
      true
      # everything required has been specified (must find out what that is)
      # what is there is correct
    end
    
    def divisions_valid?
      divisions.all?{|div| div.valid?} # && division file names are unique
    end
    
    def generate
      formats.each do |format|
        require "bindery/formats/#{format}"
        ::Bindery::Formats.const_get(format.to_s.capitalize).new(self).generate
      end
    end
  end
end
