module Bindery

  class BookBuilder
    attr_accessor :book

    Metadata = {
      :contributor => nil,
      :cover       => :special,
      :coverage    => nil,
      :creator     => nil,
      :date        => nil,
      :description => nil,
      :format      => nil,
      :identifier  => :required,
      :language    => :required,
      :publisher   => nil,
      :relation    => nil,
      :rights      => nil,
      :source      => nil,
      :subject     => nil,
      :title       => :required,
      :type        => nil
    }

    include ContentMethods

    def initialize
      self.book = ::Bindery::Book.new
    end

    def format(fmt)
      raise "unsupported format :#{fmt}" unless [:epub, :epub2, :epub3].include?(fmt)
      if fmt == :epub
        # treat :epub as an alias for :epub2 for backward compatibility
        fmt == :epub2
      end
      book.formats << fmt
    end

    def output(basename)
      raise "output already set to #{book.output}" unless book.output.nil?
      book.output = basename.to_s
    end

    def divisions
      book.divisions
    end

    # ----------------------------------------------------
    # Metadata elements

    # Allows grouping metadata elements together in a named block
    # within the book specification. Use of this method is not necessary;
    # all of the metadata methods can be called directly on the BookBuilder
    # instance. It is usually best, though, to have them clearly grouped
    # within a metadata block.
    def metadata
      yield self
    end

    def metadata_element(name, value, options={})
      name_sym = name.to_sym
      if Metadata[name_sym] == :special
        book.metadata << Bindery::Book::Metadata.new(name_sym, value, options)
      else
        book.metadata << Bindery::Book::DublinMetadata.new(name_sym, value, options)
      end
    end

    def method_missing(name, *args, &block)
      if Metadata.include?(name.to_sym)
        metadata_element(name, *args, &block)
      else
        super
      end
    end

    # TODO: Most of these could be switched to be general metadata
    # objects. Should they be?
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

    def stylesheet(css)
      book.stylesheet = css
    end

    def extra_stylesheet(css)
      book.extra_stylesheet = css
    end

  end

end
