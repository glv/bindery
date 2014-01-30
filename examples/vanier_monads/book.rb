require 'bindery'
require 'open-uri'
require 'nokogiri'
#require 'tidy_ffi'

PARTS = [
  'http://webcache.googleusercontent.com/search?q=cache:http://mvanier.livejournal.com/3917.html',
  'http://webcache.googleusercontent.com/search?q=cache:http://mvanier.livejournal.com/4305.html',
  'http://webcache.googleusercontent.com/search?q=cache:http://mvanier.livejournal.com/4586.html',
  'http://webcache.googleusercontent.com/search?q=cache:http://mvanier.livejournal.com/4647.html',
  'http://webcache.googleusercontent.com/search?q=cache:http://mvanier.livejournal.com/5103.html',
  'http://webcache.googleusercontent.com/search?q=cache:http://mvanier.livejournal.com/5343.html',
  'http://webcache.googleusercontent.com/search?q=cache:http://mvanier.livejournal.com/5406.html',
  'http://webcache.googleusercontent.com/search?q=cache:http://mvanier.livejournal.com/5846.html'
]

TITLES = [
  "Part 1: Basics",
  nil,
  nil,
  nil,
  "Part 5: Error-Handling Monads",
  "Part 6: More on Error-Handling Monads",
  "Part 7: State Monads",
  "Part 8: More on State Monads"
]

def process_part(url, i)
  file_name = "chapter_#{i+1}.xhtml_gen"
  doc = Nokogiri::HTML(open(url), nil, 'UTF-8')
  title = TITLES[i] || doc.at_css('h1.b-singlepost-title').text.sub(/^.*?Tutorial \(p(art .*?)\).*$/, 'P\\1')
  open(file_name, 'w') do |os|
    content = doc.at_css('div.b-singlepost-body')
    os.puts "<h1>#{title}</h1>"
    os.write content.serialize
  end
  [title, file_name]
end

Bindery.book do |b|
  b.output 'mvanier_monad_tutorial'
  b.format :epub
  
  b.title "Yet Another Monad Tutorial"
  b.author 'Mike Vanier'
  b.url 'http://glenn.mp/book/mvanier_monad_tutorial'
  b.language 'en'
  
  PARTS.each_with_index do |url, i|
    b.chapter *process_part(url, i)
  end
end
