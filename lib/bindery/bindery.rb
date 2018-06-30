module Bindery

  def self.book
    builder = ::Bindery::BookBuilder.new
    yield builder
    builder.book.generate if builder.book.valid?
  end

end
