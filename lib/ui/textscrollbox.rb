#! /usr/local/bin/ruby
# encoding: utf-8

require_relative "dialog"
require_relative "messagebox"

class TextScrollBox < MessageBox
  attr_reader :x, :y, :title

  def initialize(window, title, text, buttons, &block)
    super(window, title, buttons, &block)
    @x = 0
    @w = @window.width
    @y = 0
    @h = @window.height
    @nl = (@h / @ts).to_i - 4

    @text = text.split(/\r?\n/)

    @pos = 0
  end

  def position
    super
    @text_h = @h - @text_y - @button_h - @pad * 2
  end

  def draw
    super
    @window.rectangle(@title_x, @text_y, @title_w, @text_h, 0xff000000, 1001)
    0.upto(@nl) do |l|
      break if @pos + x >= @text.length
      w = @font.text_width(@text[@pos + l])
      @font.draw_text(@text[@pos + l], (@text_x + (@w - w) / 2).to_i, @text_y + l * @ts, 1002, 1, 1, 0xffffffff)
    end
  end

  def key_press(key)
    super
    case key
    when Gosu::KbUp       then @pos -= 1
    when Gosu::KbDown     then @pos += 1
    when Gosu::KbPageUp   then @pos -= (@nl / 2).to_i
    when Gosu::KbPageDown then @pos += (@nl / 2).to_i
    end
    @pos = [ [ (@text.length - @nl), @pos ].min, 0 ].max
  end
end
