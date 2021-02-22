#! /usr/local/bin/ruby
# encoding: utf-8

require_relative "dialog"

class WaitDialog < Dialog
  def initialize(window, title, &block)
    super(window, title, &block)
    @h = @ts + 18
    Thread.new { @block.call ; kill }
  end

  def position
    super
  end

  def draw
    super
  end
end
