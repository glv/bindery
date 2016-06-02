require 'builder'
require 'zip'
require 'bindery/extensions/zip_file'
require 'nokogiri'
require 'uri'

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

      MimeTypes = {
        '.jpg' => 'image/jpeg',
        '.png' => 'image/png',
        '.gif' => 'image/gif',
      }

      class ManifestEntry < Struct.new(:file_name, :xml_id, :mime_type)
      end

      attr_accessor :book, :manifest_entries

      def initialize(book)
        self.book = book
        book.extend BookMethods
        book.divisions.each{|division| division.extend DivisionMethods}
        self.manifest_entries = []
      end

      def generate
        File.delete(book.epub_output_file) if File.exist?(book.epub_output_file)
        Zip::ZipFile.open(book.epub_output_file, Zip::ZipFile::CREATE) do |zipfile|
          # FIXME: The mimetype file is supposed to be the first one in the Zip directory, but that doesn't seem to be happening.
          zipfile.write_uncompressed_file 'mimetype', mimetype
          zipfile.mkdir 'META-INF'
          zipfile.write_file 'META-INF/container.xml', container

          # also frontmatter, backmatter
          book.divisions.each do |division|
            write_division(division, zipfile)
          end

          zipfile.mkdir 'css'
          zipfile.write_file 'css/book.css', stylesheet

          zipfile.write_file 'book.opf', opf
          zipfile.write_file 'book.ncx', ncx
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
        xm.package('version'=>'2.0', 'xmlns'=>'http://www.idpf.org/2007/opf', 'unique-identifier'=>'BookId') {

          xm.metadata('xmlns:dc'=>'http://purl.org/dc/elements/1.1/', 'xmlns:opf'=>'http://www.idpf.org/2007/opf') {
            # required elements
            xm.dc :title, book.full_title
            xm.dc :language, book.language
            xm.dc :identifier, book.url, ident_options('opf:scheme'=>'URL') if book.url
            xm.dc :identifier, book.isbn, ident_options('opf:scheme'=>'ISBN') if book.isbn

            # optional elements
            xm.dc :creator, book.author, 'opf:role'=>'aut' if book.author
          }

          xm.manifest {
            book.divisions.each{|division| division.write_item(xm)}
            # also frontmatter, backmatter
            xm.item 'id'=>'stylesheet', 'href'=>'css/book.css', 'media-type'=>'text/css'
            manifest_entries.each do |entry|
              xm.item 'id'=>entry.xml_id, 'href'=>entry.file_name, 'media-type'=>entry.mime_type
            end
            # xm.item 'id'=>'myfont', 'href'=>'css/myfont.otf', 'media-type'=>'application/x-font-opentype'
            xm.item 'id'=>'ncx', 'href'=>'book.ncx', 'media-type'=>'application/x-dtbncx+xml'
          }

          xm.spine('toc'=>'ncx') {
            book.divisions.each{|division| division.write_itemref(xm)}
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
            xm.text book.full_title
          }

          xm.docAuthor {
            xm.text book.author
          }

          xm.navMap {
            play_order = 0

            # also frontmatter, backmatter
            book.divisions.each do |division|
              play_order += 1
              play_order = division.write_navpoint(xm, play_order)
            end
          }
        }
      end
      
      def write_division(division, zipfile)
        save_options = Nokogiri::XML::Node::SaveOptions
        File.open(division.file, 'r:UTF-8') do |ch_in|
          doc = Nokogiri.HTML(ch_in.read)
          include_images(doc, zipfile) if division.include_images?
          zipfile.get_output_stream(division.epub_output_file) do |ch_out|
            if division.body_only?
              # FIXME: must HTML-escape the division title
              ch_out.write %{|<?xml version="1.0" encoding="UTF-8" ?>
                             |<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
                             |<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
                             |<head>
                             |  <meta http-equiv="Content-Type" content="application/xhtml+xml; charset=utf-8" />
                             |  <title>#{division.title}</title>
                             |  <link rel="stylesheet" href="css/book.css" type="text/css" />
                             |</head>
                             |}.strip_margin
              ch_out.write doc.at('body').serialize(:save_with => (save_options::AS_XHTML | save_options::NO_DECLARATION))
              ch_out.write %{|</html>
                             |}.strip_margin
            else
              ch_out.write doc.serialize(:save_with => save_options::AS_XHTML)
            end
          end
        end
        division.divisions.each do |div|
          write_division(div, zipfile)
        end
      end

      def include_images(doc, zipfile)
        # TODO: where else can images appear? Style sheets?
        zipfile.mkdir('images') unless zip_dir_exists?(zipfile, 'images')
        doc.css('img').each do |img|
          url = img['src']
          img_fn = make_image_file_name(zipfile, url)
          # TODO: These images should be cached somewhere for multi-format runs
          begin
            open(url, 'r') do |is|
              zipfile.get_output_stream(img_fn) do |os|
                os.write is.read
              end
            end
            add_manifest_entry(img_fn)
            img['src'] = img_fn
          rescue OpenURI::HTTPError => ex
            puts "Image fetch failed: #{ex.message} (#{url})"
          end
        end
      end

      def add_manifest_entry(file_name)
        xml_id, ext = File.base_parts(file_name.gsub('/', '-'))
        manifest_entries << ManifestEntry.new(file_name, xml_id, MimeTypes[ext])
      end

      def cover
        xm = Builder::XmlMarkup.new(:indent => 2)
        xm.instruct!
        xm.declare!(:DOCTYPE, :html, :PUBLIC, '-//W3C//DTD XHTML 1.1//END', 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd')
        xm.html('xmlns'=>'http://www.w3.org/1999/xhtml') { # ??? xml:lang attribute?
          xm.head {
            xm.title "#{book.title}: Cover"
            xm.meta('http-equiv'=>'Content-Type', 'content'=>'application/xhtml+xml; charset=utf-8')
          }
          xm.body {
            xm.div('style'=>'text-align: center; page-break-after: always;') {
              if book.cover
                xm.img('src'=>"images/#{book.cover}", 'alt'=>book.title, 'style'=>'height: 100%; max-width: 100%;')
              else
                xm.h1 book.title
                xm.h2 book.subtitle if book.subtitle
                xm.h3 "by #{book.author}" if book.author
              end
            }
          }
        }
      end

      def stylesheet
        # This is a start, but needs work.
        %q{|@page {
           |  margin-top: 0.8em;
           |  margin-bottom: 0.8em;}
           |
           |body {
           |  margin-left: 1em;
           |  margin-right: 1em;
           |  padding: 0;}
           |
           |h2 {
           |  padding-top:0;
           |  display:block;}
           |
           |p {
           |  margin-top: 0.3em;
           |  margin-bottom: 0.3em;
           |  text-indent: 1.0em;
           |  text-align: justify;}
           |
           |body > p:first-child {text-indent: 0}
           |div.text p:first-child {text-indent: 0}
           |
           |blockquote p, li p {
           |  text-indent: 0.0em;
           |  text-align: left;}
           |
           |div.chapter {padding-top: 3.0em;}
           |div.part {padding-top: 3.0em;}
           |h3.section_title {text-align: center;}
           |}.strip_margin
      end

      def ident_options(opts)
        if book.isbn
          return opts.merge('id'=>'BookId') if opts['opf:scheme'] == 'ISBN'
        else
          return opts.merge('id'=>'BookId') if opts['opf:scheme'] == 'URL'
        end
        opts
      end

      def zip_dir_exists?(zipfile, dirname)
        dirname = "#{dirname}/" unless dirname =~ %r{/$}
        zipfile.entries.any?{|e| e.directory? && e.name == dirname}
      end

      def zip_file_exists?(zipfile, filename)
        zipfile.entries.any?{|e| e.name == filename}
      end

      def make_image_file_name(zipfile, url)
        uri = URI(url)
        stem, ext = File.base_parts(uri.path)
        filename = "images/#{stem}#{ext}"
        n = 0
        while zip_file_exists?(zipfile, filename)
          n += 1
          filename = "#{stem}_#{n}#{ext}"
        end
        filename
      end

      module BookMethods
        def epub_output_file
          @epub_output_file ||= "#{output}.epub"
        end

        def depth
          (divisions.map(&:depth) + [0]).max
        end

        def ident
          isbn || url
        end
      end

      module DivisionMethods

        def self.extended(obj)
          obj.divisions.each{|division| division.extend DivisionMethods}
        end

        def epub_id
          @epub_id ||= File.stemname(file)
        end

        def epub_output_file
          @epub_output_file ||= "#{epub_id}.xhtml"
        end

        def depth
          (divisions.map(&:depth) + [0]).max + 1
        end

        def write_item(xm)
          xm.item('id' => epub_id,
                  'href' => epub_output_file,
                  'media-type' => 'application/xhtml+xml')
          divisions.each{|div| div.write_item(xm)}
        end

        def write_itemref(xm)
          xm.itemref('idref' => epub_id)
          divisions.each{|div| div.write_itemref(xm)}
        end

        def write_navpoint(xm, play_order)
          xm.navPoint('class'=>'chapter', 'id'=>epub_id, 'playOrder'=>play_order) {
            xm.navLabel {
              xm.text title
            }
            xm.content 'src'=>epub_output_file
            divisions.each do |division|
              play_order += 1
              play_order = division.write_navpoint(xm, play_order)
            end
          }
          play_order
        end

      end

      module MetadataMethods
        def to_xml(builder)
          builder.meta(options.merge(:name => name, :content => value))
          %{<dc:#{name}>#{value}</dc:#{name}>}
        end
      end

      module DublinMetadataMethods
        def to_xml(builder)
          builder.dc name, value, options
        end
      end
    end
  end
end

# Notes:
# cover image file: in manifest, then in metadata as <meta name="cover" content="manifest-entry-id"/>
# cover: xhtml file, in manifest, also in spine as <itemref idref="manifest-entry-id" linear="no"/>, also in guide as <reference type="cover" title="Cover" href="cover.xhtml"/> (why does that use a direct href instead of an id ref?)
