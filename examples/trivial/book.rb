require 'bindery'

Bindery.book do |b|
  b.output 'trivial'
  b.format :epub
  
  b.title "A Trivial Bindery Example"
  b.language 'en'
  b.url 'http://glenn.mp/book/trivial_example'
  b.author 'Glenn Vanderburg'
  
  b.chapter "Chapter 1", 'chapter_1.xhtml'
  b.chapter "Chapter 2", 'chapter_2.xhtml', :body_only => false
  b.chapter "Chapter 3" do
    File.open("chapter_3.xhtml.gen", "w") do |os|
      os.write %{
        <p>Let's just write this chapter in line, shall we?</p>
        <p>It really seems easier that way, when the chapters are so short.</p>
      }
    end
    "chapter_3.xhtml.gen"
  end
end
