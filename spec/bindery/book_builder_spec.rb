require 'spec_helper'

describe Bindery::BookBuilder do
  let(:book) { subject.book }
  
  describe "#book" do
    it "returns the configured Book instance" do
      book.should be_kind_of(Bindery::Book)
    end
  end
  
  describe "#output" do
    it "stores the filename to use (minus suffix) for output book files" do
      subject.output 'foo'
      book.output.should == 'foo'
    end
    
    it "converts its argument to a string before storing it" do
      subject.output :foo
      book.output.should == 'foo'
    end
    
    it "raises an error if the output has already been set" do
      subject.output 'bar'
      expect { subject.output 'foo' }.to raise_error
    end
  end
  
  describe "#format" do
    it "raises an exception if the supplied format is unsupported" do
      expect { subject.format :interpress }.to raise_error
      expect { subject.format :mobi }.to raise_error
    end
    
    it "adds the supplied format to the list of formats to generate for this book" do
      subject.format :epub
      book.formats.should =~ [:epub]
    end
  end
  
  describe "#chapter" do
    
    context "when called without a block" do
      it "raises an exception if title or filename are not supplied" do
        expect { subject.chapter }.to raise_error(ArgumentError, "title not specified")
        expect { subject.chapter "A" }.to raise_error(ArgumentError, "file not specified")
      end
      
      it "stores a new chapter with the supplied options" do
        subject.chapter "Foo", "bar.xhtml"
        book.chapters.should have(1).elements
        book.chapters.first.title.should == "Foo"
        book.chapters.first.file.should == "bar.xhtml"
      end
    end
    
    context "when called with a block" do
      
      context "and title is supplied as an argument" do
        it "expects the block to result in a filename string" do
          expect { subject.chapter("Foo"){ 3 } }.to raise_error
        end
        
        it "stores the title and the filename as a new chapter" do
          subject.chapter("Foo"){ 'bar.xhtml' }
          book.chapters.should have(1).elements
          book.chapters.first.title.should == "Foo"
          book.chapters.first.file.should == "bar.xhtml"
        end
      end
      
      context "and title is not supplied as an argument" do
        it "expects the block to result in a hash with :title and :file options" do
          expect { subject.chapter{ "Invalid" } }.to raise_error
          expect { subject.chapter{ {:title => 'Foo'} } }.to raise_error
          expect { subject.chapter{ {:file => 'bar.xhtml'} } }.to raise_error
        end
        
        it "stores the title and the filename as a new chapter" do
          subject.chapter { {:title => 'Foo', :file => 'bar.xhtml'} }
          book.chapters.should have(1).elements
          book.chapters.first.title.should == "Foo"
          book.chapters.first.file.should == "bar.xhtml"
        end
      end
      
    end
    
  end
end