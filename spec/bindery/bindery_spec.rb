require 'spec_helper'

describe Bindery do
  describe ".book" do
    it "yields a new BookBuilder object to the block" do
      Bindery.book do |b|
        b.should be_kind_of Bindery::BookBuilder
      end
    end
    
    it "generates the book after the block returns if the book is valid" do
      Bindery.book do |b|
        b.book.expects(:valid?).once.returns(true)
        b.book.expects(:generate).once
      end
    end
    
    it "does not generate the book if the book is not valid" do
      Bindery.book do |b|
        b.book.expects(:valid?).once.returns(false)
        b.book.expects(:generate).never
      end
    end
  end
end
