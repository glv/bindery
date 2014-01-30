module Bindery
  class Division
    attr_accessor :div_type
    attr_accessor :file
    attr_accessor :title
    attr_accessor :options

    include ContentMethods
    
    def initialize(div_type, title, file, options)
      self.div_type = div_type
      self.title = title
      self.file = file
      self.options = options
    end
    
    def valid?
      true
      # ??? title specified? Is this required by the spec? Think about
      #   in what sense a chapter needs a title. Wouldn't it be nice
      #   if (say) Pratchett's books could be broken up a bit even
      #   though he doesn't have titled chapters? Aren't there books
      #   with actual chapters but no titles? Does epub provide
      #   another way to provide subdivisions without separate
      #   chapters that would break up the text flow?
      # file exists, readable
      # file content properly formed?  Does that matter?  Can we
      #   verify it? 
    end

    def divisions
      @divisions ||= []
    end
    
    def body_only?
      options.fetch(:body_only, true)
    end
    
    def include_images?
      options.fetch(:include_images, true)
    end
  end
end
