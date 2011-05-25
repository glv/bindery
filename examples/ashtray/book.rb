require 'bindery'
require 'open-uri'
require 'nokogiri'

# In March, 2011, Errol Morris published on the New York Times website
# a five-part reminiscence of a long-ago encounter with famed philosopher
# Thomas Kuhn.  It's a perfect example of the kind of thing Bindery was
# designed for.  You could always use Instapaper to allow you to read it
# later, but the fact that it's in five pieces means that it wouldn't
# appear as a single piece of writing in the Instapaper apps; additionally,
# it's long enough that you might well have to stop reading in the middle
# of one of the articles, and Instapaper doesn't remember your stopping 
# point or synch it between devices.
#
# Note: I occasionally write Bindery scripts like this to bundle writing
# from the web into a more convenient form for my own personal use.  In
# that respect, I find it no different (as a matter of copyright) than
# using a service like Instapaper.  However, it would definitely be a
# violation of Morris' and the New York Times' copyrights to distribute
# the resulting ebook to others.  Don't do that!

PARTS = [
  'http://opinionator.blogs.nytimes.com/2011/03/06/the-ashtray-the-ultimatum-part-1/',
  'http://opinionator.blogs.nytimes.com/2011/03/07/the-ashtray-shifting-paradigms-part-2/',
  'http://opinionator.blogs.nytimes.com/2011/03/08/the-ashtray-hippasus-of-metapontum-part-3/',
  'http://opinionator.blogs.nytimes.com/2011/03/09/the-ashtray-the-author-of-the-quixote-part-4/',
  'http://opinionator.blogs.nytimes.com/2011/03/10/the-ashtray-this-contest-of-interpretation-part-5/'
]

def process_part(url, i)
  file_name = "chapter_#{i+1}.xhtml_gen"
  doc = Nokogiri::HTML(open(url))
  title = doc.at_css('h1.entry-title').text.sub(/^.*?: (.*) \(Part \d\)\s*$/, '\\1')
  open(file_name, 'w') do |os|
    content = doc.at_css('div.entry-content')
    
    # This should deal with image links properly, and it doesn't yet.
    os.write content.children - content.children[0..1]
  end
  { :title => title, :file => file_name }
end

Bindery.book do |b|
  b.output 'the_ashtray'
  b.format :epub
  
  b.title "The Ashtray"
  b.author 'Errol Morris'
  b.url 'http://glenn.mp/book/the_ashtray'
  b.language 'en'
  
  PARTS.each_with_index do |url, i|
    b.chapter { process_part(url, i) }
  end
end
