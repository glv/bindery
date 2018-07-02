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
    module EpubGeneral

      class ManifestEntry < Struct.new(:file_name, :xml_id, :mime_type)
      end

      attr_accessor :book, :manifest_entries

      def initialize(book)
        self.book = book
        self.manifest_entries = []
      end

      def mime_types
        {
          '.jpg' => 'image/jpeg',
          '.png' => 'image/png',
          '.gif' => 'image/gif',
        }
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

          unless book.javascript_files.empty?
            zipfile.mkdir 'js'
            book.javascript_files.each do |javascript_file|
              zipfile.write_file "js/#{javascript_file}", IO.read(javascript_file)
            end
          end

          zipfile.write_file 'book.opf', opf
          generate_special(zipfile)
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
        xm.package('version'=>epub_version, 'xmlns'=>'http://www.idpf.org/2007/opf', 'unique-identifier'=>'BookId') {
          write_opf_metadata(xm)
          write_opf_manifest(xm)
          write_opf_spine(xm)

          # xm.guide {
          #   xm.reference 'type'='loi', 'title'=>'List of Illustrations', 'href'=>'appendix.html#figures'
          # }
        }
      end

      def write_opf_manifest(xm)
        xm.manifest {
          write_toc_manifest_entry(xm)

          extra_properties = if book.javascript_files.empty?
                               {}
                             else
                               {'properties' => 'scripted'}
                             end
          book.divisions.each{|division| division.write_item(xm, extra_properties)}
          # also frontmatter, backmatter
          xm.item 'id'=>'stylesheet', 'href'=>'css/book.css', 'media-type'=>'text/css'
          book.javascript_files.each do |javascript_file|
            xm.item 'id'=>javascript_file, 'href'=>"js/#{javascript_file}", 'media-type'=>'text/javascript'
          end
          manifest_entries.each do |entry|
            xm.item 'id'=>entry.xml_id, 'href'=>entry.file_name, 'media-type'=>entry.mime_type
          end
          # xm.item 'id'=>'myfont', 'href'=>'css/myfont.otf', 'media-type'=>'application/x-font-opentype'
        }
      end

      def write_division(division, zipfile)
        File.open(division.file, 'r:UTF-8') do |ch_in|
          doc = Nokogiri.HTML(ch_in.read)
          include_images(doc, zipfile, division.options[:url]) if division.include_images?
          zipfile.get_output_stream(division.epub_output_file) do |ch_out|
            if division.body_only?
              wrap_body(ch_out, division, doc)
            else
              body = doc.at('body')
              book.javascript_files.each do |javascript_file|
                body.add_child %Q{
                  <script src="js/#{javascript_file}" type="text/javascript" charset="utf-8"></script>
                }
              end
              ch_out.write doc.serialize(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XHTML)
            end
          end
        end
        division.divisions.each do |div|
          write_division(div, zipfile)
        end
      end

      def include_images(doc, zipfile, base_url)
        # TODO: where else can images appear? Style sheets?

        doc.css('img').each do |img|
          url = img['src']
          img_fn = make_image_file_name(zipfile, url)
          # TODO: These images should be cached somewhere for multi-format runs

          full_url = if base_url.nil?
                       url
                     else
                       URI.join(base_url, url)
                     end

          begin
            open(full_url, 'r') do |is|
              zipfile.mkdir('images') unless zip_dir_exists?(zipfile, 'images')
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
        manifest_entries << ManifestEntry.new(file_name, xml_id, mime_types[ext])
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
        return book.stylesheet if book.stylesheet

        base_stylesheet = %q{|@page {
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
                             |  margin-top: 0;
                             |  margin-bottom: 0;
                             |  text-indent: 2.0em;
                             |  text-align: justify;}
                             |
                             |code {
                             |  text-indent: 0;}
                             |
                             |:not(p) + p {text-indent: 0}
                             |body > p:first-child {text-indent: 0}
                             |div.text p:first-child {text-indent: 0}
                             |
                             |blockquote p, li p {
                             |  text-align: left;}
                             |
                             |div.chapter {padding-top: 3.0em;}
                             |div.part {padding-top: 3.0em;}
                             |h3.section_title {text-align: center;}
                             |}.strip_margin
        [base_stylesheet, book.extra_stylesheet].compact.join("\n")
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

        def epub_id
          @epub_id ||= File.stemname(file)
        end

        def epub_output_file
          @epub_output_file ||= "#{epub_id}.xhtml"
        end

        def depth
          (divisions.map(&:depth) + [0]).max + 1
        end

        def write_item(xm, extra_properties={})
          xm.item extra_properties.merge('id' => epub_id,
                                         'href' => epub_output_file,
                                         'media-type' => 'application/xhtml+xml')
          divisions.each{|div| div.write_item(xm, extra_properties)}
        end

        def write_itemref(xm)
          xm.itemref('idref' => epub_id)
          divisions.each{|div| div.write_itemref(xm)}
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
