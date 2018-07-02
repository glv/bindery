require 'builder'
require 'zip'
require 'bindery/extensions/zip_file'
require 'nokogiri'
require 'open-uri'
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
    class Epub2
      include EpubGeneral

      def initialize(book)
        super
        book.extend BookMethods
        book.divisions.each{|division| division.extend DivisionMethods}
      end

      def epub_version
        '2.0'
      end

      def generate_special(zipfile)
        zipfile.write_file 'book.ncx', ncx
      end

      def write_opf_metadata(xm)
        xm.metadata('xmlns:dc'=>'http://purl.org/dc/elements/1.1/', 'xmlns:opf'=>'http://www.idpf.org/2007/opf') {
          # required elements
          xm.dc :title, book.full_title
          xm.dc :language, book.language
          xm.dc :identifier, book.url, ident_options('opf:scheme'=>'URL') if book.url
          xm.dc :identifier, book.isbn, ident_options('opf:scheme'=>'ISBN') if book.isbn

          # optional elements
          xm.dc :creator, book.author, 'opf:role'=>'aut' if book.author
          book.metadata.each do |metadata|
            xm.dc metadata.name, metadata.value, metadata.options
          end
        }
      end

      def write_toc_manifest_entry(xm)
        xm.item 'id'=>'ncx', 'href'=>'book.ncx', 'media-type'=>'application/x-dtbncx+xml'
      end

      def write_opf_spine(xm)
        xm.spine('toc'=>'ncx') {
          book.divisions.each{|division| division.write_itemref(xm)}
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

      def wrap_body(div_out, division, doc)
        save_options = Nokogiri::XML::Node::SaveOptions
        div_out.write %{|<?xml version="1.0" encoding="UTF-8" ?>
                        |<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
                        |<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
                        |<head>
                        |  <meta http-equiv="Content-Type" content="application/xhtml+xml; charset=utf-8" />
                        |  <title>#{Builder::XChar.encode(division.title)}</title>
                        |  <link rel="stylesheet" href="css/book.css" type="text/css" />
                        |</head>
                        |}.strip_margin
        body = doc.at('body')
        book.javascript_files.each do |javascript_file|
          body.add_child %Q{
            <script src="js/#{javascript_file}" type="text/javascript" charset="utf-8"></script>
          }
        end
        div_out.write body.serialize(:save_with => (save_options::AS_XHTML | save_options::NO_DECLARATION))
        div_out.write %{|</html>
                        |}.strip_margin
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

      def ident_options(opts)
        if book.isbn
          return opts.merge('id'=>'BookId') if opts['opf:scheme'] == 'ISBN'
        else
          return opts.merge('id'=>'BookId') if opts['opf:scheme'] == 'URL'
        end
        opts
      end

      module BookMethods
        include EpubGeneral::BookMethods
      end

      module DivisionMethods
        include EpubGeneral::DivisionMethods

        def self.extended(obj)
          obj.divisions.each{|division| division.extend self}
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
