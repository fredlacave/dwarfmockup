#! /usr/local/bin/ruby
# encoding: utf-8

require_relative 'tile'
require_relative 'shape'

require 'rmagick'

class Grid
  include Enumerable
  
  attr_reader :width, :height, :level
  attr_accessor :dirty

  def initialize(width, height, level)
    @width = width
    @height = height
    @level = level
    @tiles = nil
    @dx1 = @dx2 = @dy1 = @dy2 = nil
    @calc_dirty = true
    @area = @height * @width
  end

  # @return [Grid]
  def clear
    @tiles = Array.new(width * height * 4)
    self
  end

  # @return [String]
  def to_s
    "#{@width}x#{@height}@#{@level}"
  end

  # @return [String]
  def inspect
    r = to_s.dup
    pz = -1
    py = -1
    self.each do |v, x, y, z|
      if z != pz 
        r << "\n"
        pz = z
      end
      if y != py
        r << "\n"
        py = y
      end
      if v.is_a? GroundTile
        r << v.type
      elsif v.nil?
        r << "xx"
      else
        r << "%02s" % [ v.type ]
      end
    end
    r << "**\n"
    r
  end

  # @return [Tile]
  def [](x, y, z)
    if include? x, y, z
      @tiles[z * @area + y * @width + x]
    else
      nil
    end
  end
  
  def []=(x, y, z, v)
    if include? x, y, z
      @tiles[z * @area + y * @width + x] = v
      set_dirty(x, y, z) if z == 0
    else
      raise "Tile out of bound : (#{x}, #{y}, #{z}) - #{self}"
    end
  end
  
  def no_dirty
    oc = @calc_dirty
    @calc_dirty = false
    yield
    @calc_dirty = oc
  end
  
  def set_dirty(x, y, z = 0)
    return unless @calc_dirty
    @dirty = true
    @dx1 = ((@dx1.nil? || x < @dx1) ? x : @dx1)
    @dx2 = ((@dx2.nil? || x > @dx2) ? x : @dx2)
    @dy1 = ((@dy1.nil? || y < @dy1) ? y : @dy1)
    @dy2 = ((@dy2.nil? || y > @dy2) ? y : @dy2)
    nil
  end
    
  def set_clean
    @dx1 = @dx2 = @dy1 = @dy2 = nil
  end
  
  # @return [Tile]
  def top_cell(z = 0)
    self[@width / 2, 0, z]
  end

  # @return [Tile]
  def left_cell(z = 0)
    self[0, @height / 2, z]
  end

  # @return [Tile]
  def right_cell(z = 0)
    self[@width, @height / 2, z]
  end

  # @return [Tile]
  def bottom_cell(z = 0)
    self[@width / 2, @height, z]
  end

  def yield_dirty(v, x, y, z, &block)
    t = v.type.dup if v
    if v.nil? && z == 0
      i = x + y * @width + z * @area
      v = GroundTile.new(nil, $main.res.df_color(:dgray))
      @tiles[i] = v
    end
    block.call v, x, y, z
    set_dirty(x, y, z) if v && v.type != t
  end

  def provide(x, y, z, &block)
    i = x + y * @width + z * @area
    v = @tiles[i]
    if v.nil?
      v = case z
          when 0 then GroundTile.new(nil, $main.res.df_color(:dgray))
          when 1 then ItemTile.new('d')
          when 2 then CommandTile.new('s-')
          when 3 then CommandTile.new('a-')
          end
      @tiles[i] = v
    end
    t = v.type.dup
    block.call v, x, y, z
    set_dirty(x, y, z) if v && v.type != t
  end

  def each(&block)
    @tiles.each_with_index do |v, i|
      x = i % @width
      y = (i / @width) % @height
      z = i / (@height * @width)
      yield_dirty v, x, y, z, &block
    end
  end

  def quick_window(x, y, z, w, h, d, gen = true, send_nils = false)
    Shape.window(x, y, z, w, h, d) do |sx, sy, sz|
      i = sx + sy * @width + sz * @area
      if v = @tiles[i]
        yield v, sx, sy, sz
      else
        if sz == 0 && gen
          v = GroundTile.new(nil, $main.res.df_color(:dgray))
          @tiles[i] = v
          yield v, sx, sy, sz
        elsif send_nils
          yield nil, sx, sy, sz
        end
      end

    end
  end

  def quick_each(gen = true)
    @tiles.each_with_index do |v, i|
      x = i % @width
      y = (i / @width) % @height
      z = i / (@height * @width)
      if v.nil? && z == 0 && gen
        v = GroundTile.new(nil, $main.res.df_color(:dgray))
        @tiles[i] = v
      end
      yield v, x, y, z
    end
  end

  def include?(x, y, z = 0)
    (0..@width - 1).include?(x) &&
    (0..@height - 1).include?(y) &&
    (0..3).include?(z)
  end
  
  def dirty?
    @dirty
  end
  
  def extract(x, y, z, w, h, d)
    g = Grid.new(w, h,@level).clear
    g.no_dirty do
      quick_window(x, y, z, w, h, d, false) do |v, sx, sy , sz|
        g[sx - x, sy - y, sz - z] = v.dup
      end
    end
    g.set_clean
    g
  end

  def used_range
    minx = miny = 99999
    maxx = maxy = 0
    self.quick_each(false) do |v, x, y, z|
      if v.is_a?(Tile) && !v.unknown?
        miny = [ miny, y ].min
        maxy = [ maxy, y ].max
        minx = [ minx, x ].min
        maxx = [ maxx, x ].max
      end
    end
    [ (minx..maxx), (miny..maxy) ]
  end
  
  def window(x, y, z, w, h, d, &block)
    Shape.window(x, y, z, w, h, d) do |sx, sy, sz|
      v = self[sx, sy, sz]
      yield_dirty v, sx, sy, sz, &block
    end
  end

  def window_range(rx, ry, rz, &block)
    Shape.window_range(rx, ry, rz) do |sx, sy, sz|
      v = self[sx, sy, sz]
      yield_dirty v, sx, sy, sz, &block
    end
  end

  def refresh_tiles(hard = false)
    if @dx1
      # Eeew.
      (hard ? 2 : 1).times do
        window_range((@dx1 - 1)..(@dx2 + 1), (@dy1 - 1)..(@dy2 + 1), 0..0) do |v, x, y, z|
          v.set_tile([ self[x,     y - 1, z], self[x,     y + 1, z],
                       self[x - 1, y,     z], self[x + 1, y,     z],
                       self[x - 1, y - 1, z], self[x - 1, y + 1, z],
                       self[x + 1, y - 1, z], self[x + 1, y + 1, z] ])
        end
      end
      @dx1 = @dx2 = @dy1 = @dy2 = nil
    end
  end

  # @return [Magick::Image]
  # def to_image()
  #   sx, sy = used_range
  #   unless sx.first == 99999
  #     w = sx.max - sx.min + 1
  #     h = sy.max - sy.min + 1
  #     x0 = sx.min
  #     y0 = sy.min
  #     i = Magick::Image.new(w, h) { |i| i.background_color = 'black' }
  #     i.view(0, 0, w, h) do |vw|
  #       self.quick_window(x0, y0, 0, w, h, 1) do |v, x, y, z|
  #         vw[x - x0][y - y0] = case v.type[0]
  #                   when '@' then 'black'
  #                   when '#' then 'gray'
  #                   when '.' then 'darkgray'
  #                   when '_' then 'black'
  #                   else           'red'
  #                   end
  #       end
  #     end
  #     i
  #   end
  # end
end
