#! /usr/local/bin/ruby
# encoding: utf-8

require_relative "dialog"

class MessageBox < Dialog
  attr_reader :x, :y, :title

  def initialize(window, title, buttons, &block)
    super(window, title, &block)

    @h = @ts * 2 + @pad * 7

    if buttons.is_a? Hash
      @buttons = buttons.to_a
    else
      @buttons = buttons.inject([]) { |a, v| a << [v, v ] }
    end
    @buttons_count = @buttons.count

    @ok_b     = @buttons.index { |e| e[0] == :ok || e[0] == :yes || e[0] == :default }
    @cancel_b = @buttons.index { |e| e[0] == :cancel } || @ok_b

    @title = title
  end

  def position
    super
    @button_y = @y + @h - @pad * 3 - @ts
    @button_x = @title_x
    @button_w = (@w - (@title_x - @x) * 2) / @buttons_count
    @button_h = @ts + @pad * 2
    @button_ty = @button_y + @pad
  end

  def draw
    super
    # Buttons
    bi = 0
    p = hit_test || -1
    @buttons.each do |k, v|
      bx = @button_x + bi * @button_w
      @window.rectangle(bx, @button_y, @button_w - @pad, @button_h, (p == bi ? 0xffcccccc : 0xffffffff), 1001)
      tw = @font.text_width(v)
      @font.draw_text(v, bx + (@button_w - tw) / 2, @button_ty, 1002, 1, 1, 0xff000000)
      bi += 1
    end
  end

  def click
    action(hit_test)
  end

  def action(p)
    if p
      kill
      @block.call(@buttons[p][0], (p == @cancel_b)) if @block
    end
  end

  def key_press(key)
    if (key == Gosu::KbEnter || key == Gosu::KbReturn) && @ok_b
      kill
      @block.call(@buttons[@ok_b][0], false) if @block
    elsif key == Gosu::KbEscape && @cancel_b
      kill
      @block.call(@buttons[@cancel_b][0], true) if @block
    elsif ('a'..'z').include?(l = @window.button_id_to_char(key))
      action(@buttons.index { |b| b[1][0, 1].downcase == l })
    end
  end

  def hit_test
    if @window.mouse_x >= @button_x && @window.mouse_x <= @button_x + (@button_w * @buttons_count) && @window.mouse_y >= @button_y && @window.mouse_y <= @button_y + @button_h
      ((@window.mouse_x - @button_x) / @button_w).to_i
    else
      nil
    end
  end
end

class InfoBox < MessageBox
  def initialize(window, title, &block)
    super(window, title, { :ok => "Ok" }, &block)
  end
end

class OkCancelBox < MessageBox
  def initialize(window, title, &block)
    super(window, title, { :ok => "Ok", :cancel => "Cancel" }, &block)
  end
end

class YesNoBox < MessageBox
  def initialize(window, title, &block)
    super(window, title, { :yes => "Yes", :no => "No" }, &block)
    @cancel_b = 1
  end
end

class YesNoCancelBox < MessageBox
  def initialize(window, title, &block)
    super(window, title, { :yes => "Yes", :no => "No", :cancel => "Cancel" }, &block)
  end
end