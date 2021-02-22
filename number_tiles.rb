#! /usr/local/bin/ruby
# encoding: utf-8

ocra = ENV['OCRA_EXECUTABLE'] rescue nil

if Gem.win_platform?
  if ocra && !ocra.empty?
    EXEC_PATH = File.dirname(File.expand_path(__FILE__)).gsub(/\//, '\\')
    IMAGE_MAGICK_PATH = EXEC_PATH + "\\vendor\\ImageMagick-6.6.9-Q8"
    ENV['PATH'] = IMAGE_MAGICK_PATH + ";" + ENV['PATH']
    APP_PATH = File.dirname(File.expand_path(ocra))
  else
    require 'win32/api'
    APP_PATH = File.dirname(File.expand_path(__FILE__))
  end
else
  APP_PATH = File.dirname(File.expand_path(__FILE__))
end

require 'gosu'
require 'opengl'
require 'rmagick'

input = ARGV[0]
ts = ARGV[1].to_i


class W < Gosu::Window
  def initialize(input, ts)
    @ts = ts
    @input = input
    super(48 * ts , 48 * ts, false)
    @tiles = Gosu::Image.load_tiles(self, input, ts, ts, true)
    self.caption = ARGV[0]
  end

  def draw
    0.upto(255) do |n|
      t = @tiles[n]
      x = (n / 48) * 8
      y = n % 48
      t.draw(x * @ts, y * @ts, 0)
      t = Gosu::Image.from_text($main, ":%3d" % [ n ], 'Arial', @ts)
      t.draw((x+1) * @ts, y * @ts, 0)
      #i.insert(t, (x+1) * ts, y * ts)
    end
  end
end

$main = W.new(input, ts)
$main.show

