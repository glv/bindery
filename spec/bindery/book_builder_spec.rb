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
  
  describe "#div" do
    
    it "raises an exception if title or filename are not supplied" do
      expect { subject.div("chapter", nil, "fn") }.to raise_error(ArgumentError, "title not specified")
      expect { subject.div("chapter", "A", nil) }.to raise_error(ArgumentError, "file not specified")
    end

    it "stores a new division with the supplied options" do
      subject.div 'excerpt', "Foo", "bar.xhtml", :a => :b
      book.divisions.should have(1).elements
      div = book.divisions.first
      div.div_type.should == 'excerpt'
      div.title.should == "Foo"
      div.file.should == "bar.xhtml"
      div.options.should include(:a => :b)
    end
    
  end

  %w[chapter section part appendix].each do |div_type|
    describe "##{div_type}" do
      it "calls #div with the appropriate type" do
        subject.expects(div_type.to_sym).once
        subject.send(div_type, :title, :filename, {:a => :b})
      end
    end
  end

end
