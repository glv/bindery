module Bindery
  class Chapter
    attr_accessor :file
    attr_accessor :title
    attr_accessor :options
    
    def initialize(title, file, options)
      self.title = title
      self.file = file
      self.options = options
    end
    
    def valid?
      true
      # title specified
      # file exists, readable
      # file content properly formed?  Does that matter?  Can we verify it?
    end
    
    def body_only?
      options.fetch(:body_only, true)
    end
  end
end
