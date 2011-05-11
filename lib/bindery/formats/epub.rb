require 'builder'
require 'zip'
require 'bindery/extensions/zip_file'

module Bindery
  module Formats
    
    # Builds an EPUB book file from the book description.
    #
    # The {EPUB Wikipedia entry}[http://en.wikipedia.org/wiki/EPUB] provides a nice, concise overview of the EPUB format.
    #
    # For more precise details:
    # * The overall structure of an EPUB file is documented in
    #   {Open Container Format (OCF) 2.0.1 - Recommended Specification}[http://idpf.org/epub/20/spec/OCF_2.0.1_draft.doc].
    # * The format of the OPF file is documented in
    #   {Open Packaging Format (OPF) 2.0.1 - Recommended Specification}[http://idpf.org/epub/20/spec/OPF_2.0.1_draft.htm].
    # * The format of the NCX file is documented in
    #   {Section 8 of "Specifications for the Digital Talking Book"}[http://www.niso.org/workrooms/daisy/Z39-86-2005.html#NCX].
    # * Details of the format of other files allowed in EPUB documents are found in
    #   {Open Publication Structure (OPS) 2.0.1 - Recommended Specification}[http://idpf.org/epub/20/spec/OPS_2.0.1_draft.htm].
    class Epub
      
      attr_accessor :book
      
      def initialize(book)
        self.book = book
        book.extend BookMethods
        book.chapters.each{|chapter| chapter.extend ChapterMethods}
      end
      
      def generate
        File.delete(book.epub_output_file) if File.exist?(book.epub_output_file)
        Zip::ZipFile.open(book.epub_output_file, Zip::ZipFile::CREATE) do |zipfile|
          # FIXME: The mimetype file is supposed to be the first one in the Zip directory, but that doesn't seem to be happening.
          zipfile.write_file 'mimetype', mimetype
          zipfile.mkdir 'META_INF'
          zipfile.write_file 'META_INF/container.xml', container
          zipfile.write_file 'book.opf', opf
          zipfile.write_file 'book.ncx', ncx
          
          # also frontmatter, backmatter
          book.chapters.each do |chapter|
            write_chapter(chapter, zipfile)
          end
          
          # zipfile.mkdir 'images'
          # add image files in images directory
          
          zipfile.mkdir 'css'
          zipfile.write_file 'css/book.css', stylesheet
        end
      end
            
      def mimetype
        # the mimetype file must be the first file in the archive
        # it must be ASCII, uncompressed, and unencrypted
        'application/epub+zip'
      end
      
      def container
        %q{|<?xml version="1.0" encoding="UTF-8" ?>
           |<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
           |  <rootfiles>
           |    <rootfile full-path="book.opf" media-type="application/oebps-package+xml"/>
           |  </rootfiles>
           |</container>
           |}.strip_margin
      end
      
      def opf
        xm = Builder::XmlMarkup.new(:indent => 2)
        xm.instruct!
        xm.package('version'=>'2.0', 'xmlns'=>'http://www.idpf.org/2007/opf', 'unique_identifier'=>'BookId') {
          
          xm.metadata('xmlns:dc'=>'http://purl.org/dc/elements/1.1/', 'xmlns:opf'=>'http://www.idpf.org/2007/opf') {
            # required elements
            xm.dc :title, book.title
            xm.dc :language, book.language
            xm.dc :identifier, book.url, ident_options('opf:scheme'=>'URL') if book.url
            xm.dc :identifier, book.isbn, ident_options('opf:scheme'=>'ISBN') if book.isbn            
            
            # optional elements
            xm.dc :creator, book.author, 'opf:role'=>'aut' if book.author
          }
          
          xm.manifest {
            book.chapters.each{|chapter| xm.item 'id'=>chapter.epub_id, 'href'=>chapter.epub_output_file, 'media-type'=>'application/xhtml+xml'}
            # also frontmatter, backmatter
            xm.item 'id'=>'stylesheet', 'href'=>'css/book.css', 'media-type'=>'text/css'
            # xm.item 'id'=>'ch1-pic', 'href'=>'images/ch1-pic.png', 'media-type'=>'image/png'
            # xm.item 'id'=>'myfont', 'href'=>'css/myfont.otf', 'media-type'=>'application/x-font-opentype'
            xm.item 'id'=>'ncx', 'href'=>'book.ncx', 'media-type'=>'application/x-dtbncx+xml'
          }
          
          xm.spine('toc'=>'ncx') {
            book.chapters.each{|chapter| xm.itemref 'idref'=>chapter.epub_id}
          }
          
          # xm.guide {
          #   xm.reference 'type'='loi', 'title'=>'List of Illustrations', 'href'=>'appendix.html#figures'
          # }
        }
      end
      
      def ncx
        xm = Builder::XmlMarkup.new(:indent => 2)
        xm.instruct!
        xm.declare!(:DOCTYPE, :ncx, :PUBLIC, '-//NISO//DTD ncx 2005-1//EN', 'http://www.daisy.org/z3986/2005/ncx-2005-1.dtd')
        xm.ncx('version'=>'2005-1', 'xml:lang'=>'en', 'xmlns'=>'http://www.daisy.org/z3986/2005/ncx/') {
          xm.head {
            xm.meta 'name'=>'dtb:uid', 'content'=>book.ident
            xm.meta 'name'=>'dtb:depth', 'content'=>book.depth
            xm.meta 'name'=>'dtb:totalPageCount', 'content'=>0
            xm.meta 'name'=>'dtb:maxPageNumber', 'content'=>0
          }
          
          xm.docTitle {
            xm.text book.title
          }
          
          xm.docAuthor {
            xm.text book.author
          }
          
          xm.navMap {
            play_order = 1
            
            # also frontmatter, backmatter
            book.chapters.each do |chapter|
              xm.navPoint('class'=>'chapter', 'id'=>chapter.epub_id, 'playOrder'=>play_order) {
                xm.navLabel {
                  xm.text chapter.title
                }
              }
              xm.content 'src'=>chapter.epub_output_file
              play_order += 1
            end
          }
        }
      end
      
      def write_chapter(chapter, zipfile)
        if chapter.body_only?
          zipfile.get_output_stream(chapter.epub_output_file) do |os|
            # FIXME: must HTML-escape the chapter title
            os.write %{|<?xml version="1.0" encoding="UTF-8" ?>
                       |<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
                       |<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
                       |<head>
                       |  <meta http-equiv="Content-Type" content="application/xhtml+xml; charset=utf-8" />
                       |  <title>#{chapter.title}</title>
                       |  <link rel="stylesheet" href="css/book.css" type="text/css" />
                       |</head>
                       |<body>
                       |}.strip_margin
            os.write IO.read(chapter.file)
            os.write %{|</body>
                       |</html>
                       |}.strip_margin
          end
        else
          zipfile.add(chapter.epub_output_file, chapter.file)
        end
      end
      
      def image
      end
      
      def stylesheet
        %{}
      end
      
      def ident_options(opts)
        if book.isbn
          return opts.merge('id'=>'BookId') if opts['opf:scheme'] == 'ISBN'
        else
          return opts.merge('id'=>'BookId') if opts['opf:scheme'] == 'URL'
        end
        opts
      end
      
      module BookMethods
        def epub_output_file
          @epub_output_file ||= "#{output}.epub"
        end
        
        def depth
          1
        end
        
        def ident
          isbn || url
        end
      end
      
      module ChapterMethods
        def epub_id
          @epub_id ||= File.basename(file, File.extname(file))
        end
        
        def epub_output_file
          @epub_output_file ||= "#{epub_id}.xhtml"
        end
      end
    end
  end
end
