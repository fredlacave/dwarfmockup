#! /usr/local/bin/ruby
# encoding: utf-8

require 'gosu'
require 'singleton'

class ResourceLoadError < Exception ; end

class Resource
  class << self
    # @!method instance
    #   @return [Preferences]
  end
  include Singleton

  def setup(dir)
    @dir = dir
    @df_colors = Hash.new { |h, v| h[v] = 0xff000000 }
    File.read("#{@dir}/df/colors.txt").scan(/\[([^_]+)_([RGB]):([^\]]+)\]/).each do |k, c, v|
      k = k.downcase.to_sym
      @df_colors[k] += v.to_i * (case c when 'R' then 0x10000 when 'G' then 0x100 else 1 end)
    end
    @prefs = Preferences.instance
  end

  def tiles(name, size)
    fn = File.join(@prefs[:tiles_dir], name + '.png')
    raise ResourceLoadError.new("Tiles load error : #{fn} not found") unless File.exist? fn
    raise ResourceLoadError.new("Invalid tile size : #{size}") unless size.to_i > 0 && size.to_i < 100
    Gosu::Image.load_tiles($main, fn, size, size, true)
  end

  # @return [Gosu::Font] font
  def default_font
    font(@prefs[:font_name], @prefs[:tile_size])
  end

  def default_font_name
    font_name(@prefs[:font_name])
  end

  def default_tiles
    tiles(@prefs[:tiles_name], @prefs[:tile_size])
  end

  def font(name, size)
    fn = font_name(name)
    Gosu::Font.new($main, fn, size)
  end
  
  def font_name(name)
    fn = File.join(@prefs[:fonts_dir], name + '.ttf')
    raise ResourceLoadError.new("Font load error : #{fn} not found") unless File.exist? fn
    fn
  end
  
  def df_color(name)
    @df_colors[name.to_sym]
  end

  def file_contents(name)
    File.read(File.join(@dir), name)
  end
end

