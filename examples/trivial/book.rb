require 'bindery'

Bindery.book do |b|
  b.output 'trivial'
  b.format :epub
  
  b.title "A Trivial Bindery Example"
  b.author 'Glenn Vanderburg'
  b.url 'http://glenn.mp/book/trivial_example'
  b.language 'en'
  
  b.chapter "Chapter 1", 'chapter_1.xhtml'
  b.chapter "Chapter 2", 'chapter_2.xhtml', :body_only => false

  # It's good practice to have a way to distinguish source files from
  # those generated as part of the build, so you can have a Rake task
  # or something to clean up the intermediate files.
  fn = 'chapter_3.xhtml_gen'
  File.open(fn, 'w') do |os|
    os.write %{
      <p>Let's just write this chapter in line, shall we?</p>
      <p>It seems easier that way, when the chapters are so short.</p>
    }
  end
  b.chapter "Chapter 3", fn

  b.part("Appendices", 'appendices.xhtml') do |div|
    div.appendix "Appendix 1: Errata", 'errata.xhtml'
    div.appendix "Appendix 2: Index", 'index.xhtml'
  end

  b.part "Colophon", 'colophon.xhtml'
end
