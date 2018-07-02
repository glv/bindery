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
    class Epub3
      include EpubGeneral

      def initialize(book)
        super
        book.extend BookMethods
        book.divisions.each{|division| division.extend DivisionMethods}
      end

      def epub_version
        '3.0'
      end

      def mime_types
        super.merge({'.svg' => 'image/svg+xml'})
      end

      def generate_special(zipfile)
        zipfile.write_file 'toc.xhtml', toc
      end

      def write_opf_metadata(xm)
        xm.metadata('xmlns:dc'=>'http://purl.org/dc/elements/1.1/', 'xmlns:opf'=>'http://www.idpf.org/2007/opf') {
          # required elements
          xm.dc :title, book.full_title
          xm.dc :language, book.language
          xm.dc :identifier, book.url, 'id'=>'BookId' if book.url
          xm.dc :identifier, book.isbn, 'id'=>'BookId' if book.isbn

          xm.meta Time.now.utc.iso8601, 'property' => 'dcterms:modified'

          # optional elements
          xm.dc :creator, book.author, 'id'=>'Creator' if book.author
          book.metadata.each do |metadata|
            xm.dc metadata.name, metadata.value, metadata.options
          end
        }
      end

      def write_toc_manifest_entry(xm)
        xm.item 'id'=>'toc', 'properties' => 'nav', 'href'=>'toc.xhtml', 'media-type'=>'application/xhtml+xml'
      end

      def write_opf_spine(xm)
        xm.spine {
          xm.itemref('idref' => 'toc')
          book.divisions.each{|division| division.write_itemref(xm)}
        }
      end

      def toc
        xm = Builder::XmlMarkup.new(:indent => 2)
        xm.html('xmlns' => 'http://www.w3.org/1999/xhtml',
                'xmlns:epub' => 'http://www.idpf.org/2007/ops') {
          xm.head {
            xm.title book.full_title.strip
          }
          xm.body {
            xm.section('epub:type' => 'frontmatter toc') {
              xm.header {
                xm.h1 'Contents'
              }
              xm.nav('epub:type' => 'toc', 'id' => 'toc') {
                xm.ol {
                  book.divisions.each do |division|
                    division.write_toc_entry(xm)
                  end
                }
              }
            }
          }
        }
      end

      def wrap_body(div_out, division, doc)
        save_options = Nokogiri::XML::Node::SaveOptions
        div_out.write %{|<!DOCTYPE html>
                        |<html xmlns="http://www.w3.org/1999/xhtml">
                        |<head>
                        |  <meta charset="UTF-8"/>
                        |  <title>#{Builder::XChar.encode(division.title)}</title>
                        |  <link rel="stylesheet" href="css/book.css" type="text/css" />
                        |</head>
                        |}.strip_margin
        div_out.write doc.at('body').serialize(:save_with => (save_options::AS_XHTML | save_options::NO_DECLARATION))
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

      module BookMethods
        include EpubGeneral::BookMethods
      end

      module DivisionMethods
        include EpubGeneral::DivisionMethods

        def self.extended(obj)
          obj.divisions.each{|division| division.extend self}
        end

        def write_toc_entry(xm)
          xm.li('id' => epub_id) {
            xm.a(title.strip, 'href' => epub_output_file)
            unless divisions.empty?
              xm.ol {
                divisions.each do |division|
                  division.write_toc_entry(xm)
                end
              }
            end
          }
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
