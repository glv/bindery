module Bindery
  module Extensions
    module FileClassMethods
      def base_parts(fn)
        ext = File.extname(fn)
        [File.basename(fn, ext), ext]
      end
      
      def stemname(fn)
        base_parts[0]
      end
    end
  end
end

File.extend(Bindery::Extensions::FileClassMethods)
