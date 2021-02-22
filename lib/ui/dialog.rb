#! /usr/local/bin/ruby
# encoding: utf-8

class Dialog < Gosu::TextInput
  attr_reader :x, :y, :title

  def initialize(window, title, &block)
    super()

    @window = window
    window.set_input self
    @font = Resource.instance.default_font
    @ts = Preferences.instance[:tile_size]
    @pad = 3
    @x = 250
    @w = @window.width - 500
    @y = ((@window.height / 2) - (@ts * 1.5)).to_i
    @h = @ts * 2 + @pad * 6

    @title = title

    @text = nil

    @block = block

    @unpositionned = true
  end

  def position
    @title_x = @x + @pad
    @title_y = @y + @pad * 2
    @title_w = @w - @pad * 2
    @title_h = @ts
    @text_x = @title_x
    @text_y = @title_y + @title_h + @pad * 2
    @text_h = @h - (@text_y - @y)
    @text_w = @title_w
    @unpositionned = false
  end

  def filter(text)
    ''
  end

  def draw
    position if @unpositionned
    # The window itself
    @window.rectangle(@x - @pad, @y - @pad, @w + @pad * 2, @ts + @pad * 2, 0xff333333, 1000)
    @window.rectangle(@x       , @y       , @w           , @h           , 0xffdddddd, 1000)

    # Title
    @font.draw_text(@title, @title_x, @title_y, 1000, 1, 1, 0xff000000)
  end

  def hit_test
    false
  end

  def key_press(key) ; end

  def click ; end

  def kill
    @window.set_input nil
  end
end
