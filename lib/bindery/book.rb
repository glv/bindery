module Bindery
  class Book
    class Metadata < Struct.new(:name, :value, :options)
    end

    class DublinMetadata < Metadata
    end

    attr_accessor :output, :url, :isbn, :title, :language, :author, :subtitle,
                  :stylesheet, :extra_stylesheet

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

    def stylesheet=(css)
      raise "Supply either stylesheet or extra_stylesheet, not both" if extra_stylesheet
      @stylesheet = css
    end

    def extra_stylesheet=(css)
      raise "Supply either stylesheet or extra_stylesheet, not both" if stylesheet
      @extra_stylesheet = css
    end

    def javascript_files
      @javascript_files ||= []
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
        ::Bindery::Formats.const_get(format.to_s.capitalize).new(self).generate
      end
    end
  end
end
