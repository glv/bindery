module Bindery
  
  class BookBuilder
    attr_accessor :book
    
    def initialize
      self.book = ::Bindery::Book.new
    end
    
    def format(fmt)
      raise "unsupported format :#{fmt}" unless [:epub].include?(fmt)
      book.formats << fmt
    end
    
    def output(basename)
      raise "output already set to #{book.output}" unless book.output.nil?
      book.output = basename.to_s
    end
    
    def url(url)
      book.url = url
    end
    
    def isbn(isbn)
      book.isbn = isbn
    end
    
    def title(title)
      book.title = title
    end
    
    def subtitle(subtitle)
      book.subtitle = subtitle
    end
    
    def language(language)
      book.language = language
    end
    
    def author(author)
      book.author = author
    end
    
    # :call-seq:
    #   chapter(title, filename, options={})
    #   chapter(title, options={}) { ... }
    #   chapter(options={}) { ... }
    #
    # Add a chapter to the book.
    #
    # If called with a title and a filename, the chapter's content should
    # be found in the named file.
    #
    # If called with a title and a block, the block should generate or
    # retrieve the chapter's content, write it to a file, and return the
    # file name.
    #
    # If called with no parameters and a block, the block should generate
    # or retrieve the chapter's content, write it to a file, and return a
    # hash with the following keys:
    # [:title] the chapter title (required)
    # [:file]  the name of the file containing the chapter content (required)
    #
    # An options hash parameter is always allowed, and the following 
    # options are supported:
    # [:body_only] the file contains only the body of the XHTML document,
    #              and Bindery should wrap it to create a valid document.
    #              Defaults to true.
    def chapter(*args)
      default_options = {:body_only => true}
      options = default_options.merge(args.last.kind_of?(Hash) ? args.pop : {})
      if block_given?
        chapter_dynamic(options, *args){yield}
      else
        chapter_static(options, *args)
      end
    end
    
    protected
    
    def chapter_static(options, *args)
      title, file = args
      raise ArgumentError, "title not specified" if title.nil?
      raise ArgumentError, "file not specified" if file.nil?
      book.chapters << Chapter.new(title, file, options)
    end
    
    def chapter_dynamic(options, title=nil)
      if title
        file = yield
        raise "expected the block to return a filename string" unless file.kind_of?(String)
        chapter_static(options, title, yield)
      else
        info = yield
        raise "expected the block to return a hash containing :title, :file, etc." unless info.kind_of?(Hash)
        chapter_static(options, info[:title], info[:file])
      end
    end
  end
  
end
