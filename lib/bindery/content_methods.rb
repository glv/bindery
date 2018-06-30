module Bindery
  module ContentMethods

    # Add a division to the book.
    #
    # The following options are supported:
    # [:body_only] the file contains only the body of the XHTML document,
    #              and Bindery should wrap it to create a valid document.
    #              Defaults to true.
    # [:url] the URL from which the division was fetched. May be needed to
    #        provide a base URL for relative image URLs found within the
    #        division body.
    def div(div_type, title, filename, options={})
      options = {:body_only => true}.merge(options)
      raise ArgumentError, "title not specified" if title.nil?
      raise ArgumentError, "file not specified" if filename.nil?
      div = Division.new(div_type, title, filename, options)
      divisions << div
      yield div if block_given?
    end

    def chapter(title, filename, options={}, &block)
      div('chapter', title, filename, options, &block)
    end

    def section(title, filename, options={}, &block)
      div('section', title, filename, options, &block)
    end

    def part(title, filename, options={}, &block)
      div('part', title, filename, options, &block)
    end

    def appendix(title, filename, options={}, &block)
      div('appendix', title, filename, options, &block)
    end

    def index(title, filename, options={}, &block)
      div('index', title, filename, options, &block)
    end

  end
end
