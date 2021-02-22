#! /usr/local/bin/ruby
# encoding: utf-8

require_relative "dialog"

class InputBox < Dialog
  def initialize(window, title, default, &block)
    super(window, title, &block)
    self.text = default
  end

  # Disallow text bigger than the window
  def filter(text)
    if @font.text_width(self.text + text) > @text_w
      ''
    else
      text
    end
  end

  def draw
    super

    # Caret & selection positions
    pos_x = @text_x + @font.text_width(self.text[0...self.caret_pos])
    sel_x = @text_x + @font.text_width(self.text[0...self.selection_start])

    # Text input background
    @window.rectangle(@text_x - @pad, @text_y - @pad, @text_w + @pad * 2, @text_h + @pad * 2, 0xffffffff, 1000)

    # Selection background, if any
    unless self.selection_start == self.caret_pos
      @window.rectangle(sel_x, @text_y - @pad + 1, pos_x - sel_x, @text_h + @pad * 2 - 2, 0xff9999cc, 1000)
    end

    # Caret
    @window.draw_line(pos_x, @text_y - @pad + 1,           0xff3333ff,
                      pos_x, @text_y + @text_h + @pad - 2, 0xff3333ff, 1001)

    # Title
    @font.draw_text(@title, @title_x, @title_y, 1000, 1, 1, 0xff000000)

    # Text
    @font.draw_text(self.text, @text_x, @text_y, 1000, 1, 1, 0xff000000)
  end

  def click
    move_caret(@window.mouse_x) if hit_test
  end

  def key_press(key)
    if key == Gosu::KbEnter || key == Gosu::KbReturn
      kill
      @block.call(self.text, false) if @block
    elsif key == Gosu::KbEscape
      kill
      @block.call(self.text, true) if @block
    end
  end

  def hit_test
    @window.mouse_x >= @text_x &&
        @window.mouse_x <= @text_x + @text_w &&
        @window.mouse_y >= @text_y &&
        @window.mouse_y <= @text_y + @text_h
  end

  # Move the caret to mouse_x
  def move_caret(mx = @window.mouse_x)
    1.upto(self.text.length) do |i|
      if mx < x + @font.text_width(text[0...i])
        self.caret_pos = self.selection_start = i - 1
        return
      end
    end
    # Default case: right
    self.caret_pos = self.selection_start = self.text.length
  end
end
