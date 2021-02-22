#! /usr/local/bin/ruby
# encoding: utf-8

require 'gosu'
require 'rmagick'
require 'win32/api' if Gem.win_platform?

module Magick
  def Magick::gosucolor_to_rmagick(color)
    case color
    when Fixnum, Bignum
      i = color.to_s(16)
      "##{i[2..8]}#{i[0..1]}"
    when Gosu::Color
      "#%02x%02x%02x%02x" % [ color.red, color.green, color.blue, color.alpha ]
    else
      color    
    end
  end
end

module Gosu
  class Image
    def to_rmagick
      this = self
      Magick::Image.from_blob(to_blob) do
        self.format = 'RGBA'
        self.depth = 8
        self.size = "#{this.width}x#{this.height}"
      end.first
    end
  end

  class Window
    def rectangle(x, y, w, h, c, z)
      draw_quad(x,         y        , c,
                x + w - 1, y        , c,
                x + w - 1, y + h - 1, c,
                x,         y + h - 1, c,
                z)
    end

    def draw_cross(x, y, l, t, w, h, c, z)
      draw_line(l, y, c, w, y, c, z)
      draw_line(x, t, c, x, h, c, z)
    end
  end

  module Button
    KbQuote = 40
    #51 ;
    #52 :
    #53 =
    #43 µ
    #12 )
    #13 -
  end
end

class DevNull; def write(*args) ; end ; end

module Kernel
  def silent
    $stdout = DevNull.new
    $stderr = DevNull.new
    yield
    $stdout = STDOUT
    $stderr = STDERR
  end

  def de(v)
    rand(v) + 1
  end

  def pct(v)
    rand(100) <= v
  end
end
