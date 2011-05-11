# Bindery

[Bindery][] is a [Ruby][] library for generating ebooks.

Electronic book formats are rather simple (HTML, CSS, and some image files packed into a single bundle along with various bits of metadata).
But there are a lot of tricky details, and a lot of redundancy in the metadata.
Bindery aims to simplify the process.

To use Bindery, you write a simple Ruby program that describes the book's structure and important metadata.
This program is also responsible for identifying the HTML files that correspond to the book's chapters; those files might already exist, but the program can generate them on the fly as well.
Then, you simply run a [Rake][] task to run that program and generate the book.

Initially, Bindery will support generating the [EPUB][] format.
I'll work to add support for other formats when EPUB support is working well.

## Example

Here is a quick example of a Bindery program.

    require 'bindery'
    require 'active_support'
    require 'maruku'
    
    Bindery.book do |b|
      b.output 'anthology'
      b.format :epub
      
      b.title "The Great Elbonian Novel"
      b.language 'en'
      b.url 'http://glv.github.com/bindery/books/example'
      b.author 'Glenn Vanderburg'
      
      b.frontmatter 'Preface', :file => 'pref.xhtml'
      
      # process a collection of files called "chapter_1.md"
      Dir['*.md'].sort.each do |file_name|
        stem = file_name.sub(/\.md$/, '')
        system %{markdown <#{file_name} >#{stem}.xhtml}
        b.chapter stem.humanize, "#{stem}.xhtml"
      end
      
      # an alternative way to process chapters, assuming the chapters use
      # Maruku's metadata support and contain the chapter title.  (Maruku
      # is a Ruby Markdown library that supports numerous common extensions
      # to the basic Markdown syntax.)
      Dir['*.md'].sort.each do |file_name|
        b.chapter do
          output_file_name = file_name.sub(/\.md$/, '.xhtml')
          doc = Maruku.new(IO.read(file_name))
          open(output_file_name, "w") {|os| os.write(doc.to_html)}
          # return a hash with title and file info:
          { :title => doc.attributes[:title], :file => output_file_name }
        end
      end
      
      b.backmatter 'Colophon' # filename assumed to be colophon.xhtml
    end
    
## Status

Bindery is currently limited to generating EPUB books that do not contain images or other non-textual content.

It is also in a very early stage.
It's capable of generating very simple books, but many features (including the frontmatter and backmatter methods in the example above) do not work yet.
Additionally, validation is sketchy, so it's quite likely that the books you build using Bindery will not be valid EPUB files.
But the basics are there, and contributions are welcome.

Planned features include:

* options for sections (with and without section title pages) rather than just a flat chapter structure.
* additional metadata including all of [Dublin Core][].
* support for images
* support for multiple stylesheets
* support for generating Mobipocket books

## When to use Bindery

There are other systems for generating ebooks; [git-scribe][] is one of the best.
However most ebook generation systems prescribe a particular authoring format or tool.
For example, git-scribe assumes you will be using [AsciiDoc][] and [Git][], and is additionally optimized for use on [GitHub][].
Other tools are designed to work with proprietary tools such as [Microsoft Word][] or [Adobe InDesign][].
Each such format or tool has strengths and weaknesses.
For example, while AsciiDoc is an excellent tool for writing technical books, it's less well suited for novels, memoirs, or poetry.
For such tasks (and depending on your personal preferences) it may be better to write in [Markdown][] or [Textile][].

More importantly, requiring a specific format makes an ebook system difficult to use for a book that includes existing material being republished or repurposed.

Imagine that, like [Joel Spolsky][], you want to publish an anthology of [your best blog posts][joel on software], or a collection of the [best software writing from around the web][best software writing].
Or, like [Steven Johnson][], you write carefully researched books that weave together threads from many fields and disciplines, so you make use of a sophisticated research management tool like [DEVONthink][] and do a lot of your own writing in that tool (Johnson has written [two][johnson dt1] [articles][johnson dt2] describing his research and writing methods).
Or perhaps you simply want to read through the [SproutCore tutorial][], but your spare time is fragmented (and usually occurs when you're on an airplane) so you want to convert it to an ebook format so it's always available and your reader will keep track of how far you've read.

In any of those cases, the writing will exist in a format that probably doesn't match what existing ebook generation systems expect, and in some cases it will already be in the HTML format that nearly all ebook formats are based on.

Bindery is designed to support those use cases, not just brand new books written with a particular ebook system in mind.

[adobe indesign]: http://www.adobe.com/products/indesign.html
[asciidoc]: http://www.methods.co.nz/asciidoc/
[best software writing]: http://www.apress.com/9781590595008
[Bindery]: http://github.com/glv/bindery
[devonthink]: http://www.devon-technologies.com/products/devonthink/index.html
[dublin core]: http://dublincore.org/sm
[epub]: http://idpf.org/epub
[git]: http://git-scm.com/
[github]: http://github.com/
[git-scribe]: http://github.com/schacon/git-scribe
[joel on software]: http://www.apress.com/9781590593899
[joel spolsky]: http://www.joelonsoftware.com/AboutMe.html
[johnson dt1]: http://www.nytimes.com/2005/01/30/books/review/30JOHNSON.html?_r=1&oref=login
[johnson dt2]: http://boingboing.net/2009/01/27/diy-how-to-write-a-b.html
[markdown]: http://daringfireball.net/projects/markdown/
[microsoft word]: http://office.microsoft.com/word/
[rake]: http://rake.rubyforge.org/
[ruby]: http://ruby-lang.org/
[sproutcore tutorial]: http://wiki.sproutcore.com/w/page/12413071/Todos%C2%A0Intro
[steven johnson]: http://www.stevenberlinjohnson.com/
[textile]: http://www.textism.com/tools/textile/