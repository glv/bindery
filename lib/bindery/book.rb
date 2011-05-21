module Bindery
  class Book
    attr_accessor :output, :url, :isbn, :title, :language, :author, :subtitle
    
    def formats
      @formats ||= []
    end
    
    def chapters
      @chapters ||= []
    end
    
    def full_title
      title + (subtitle ? ": #{subtitle}" : '')
    end
    
    def valid?
      configuration_valid? && metadata_valid? && chapters_valid?
    end
    
    def configuration_valid?
      true
      # formats specified or correctly defaulted
      # ouput specified
      # at least one chapter
    end
    
    def metadata_valid?
      true
      # everything required has been specified (must find out what that is)
      # what is there is correct
    end
    
    def chapters_valid?
      chapters.all?{|chapter| chapter.valid?} # && chapter file names are unique
    end
    
    def generate
      formats.each do |format|
        require "bindery/formats/#{format}"
        ::Bindery::Formats.const_get(format.to_s.capitalize).new(self).generate
      end
    end
  end
end
