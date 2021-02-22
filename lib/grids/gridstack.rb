#! /usr/local/bin/ruby
# encoding: utf-8

require 'csv'
require_relative 'grid'
require_relative 'tile'
require_relative 'selection'

class GridStack
  include Enumerable

  attr_reader :levels, :width, :height, :level0
  attr_accessor :cx, :cy, :show_center
  attr_accessor :name, :comment, :selected

  attr_accessor :window_left, :window_right, :window_top, :window_bottom

  def self.default
    self.new(GRIDS, NT, NT, $main.ww, $main.wh, GRID_LEVEL_0)
  end

  def initialize(levels, width, height, window_width = $main.ww, window_height = $main.wh, level0 = 0)
    @levels = levels
    @level0 = level0
    @width = width
    @height = height
    @show_center = true
    @comment = ''
    @name = ''

    @cx = @width / 2
    @cy = @height / 2

    clear

    @selected = 0

    @level_max = @levels - @level0 - 1
    @level_min = -@level0

    @window_width = window_width
    @window_height = window_height
    @window_left = @cx - (@window_width / 2).to_i
    @window_top = @cy - (@window_height / 2).to_i
    @window_right = @window_left + @window_width - 1
    @window_bottom = @window_top + @window_height - 1
  end

  def clear
    @grids = Array.new(levels) { |l| g = Grid.new(@width, @height, l - level0 ) ; g.clear ; g }
  end

  def adjust_view_port(sel)
    while sel.x - @window_left < 5 do
      self.window_left = @window_left - 10
      break if @window_left == 0
    end
    while @window_right - sel.x < 5 do
      self.window_left = @window_left + 10
      break if @window_right == @width - 1
    end

    while sel.y - @window_top < 5 do
      self.window_top = @window_top - 10
      break if @window_top == 0
    end
    while @window_bottom - sel.y < 5 do
      self.window_top = @window_top + 10
      break if @window_bottom == @height - 1
    end
  end

  def window_left=(v)
    @window_left = [ [ v, 0 ].max, (@width - @window_width) ].min
    @window_right = @window_left + @window_width - 1
  end

  def window_top=(v)
    @window_top = [ [ v, 0 ].max, (@height - @window_height) ].min
    @window_bottom = @window_top + @window_height - 1
  end

  def [](v)
    @grids[v]
  end

  def []=(v, grid)
    @grids[v] = grid
  end

  # @return [Grid]
  def grid(delta = 0)
    if @selected + delta <= @level_max && @selected + delta >= @level_min
      @grids[@selected + @level0 + delta]
    end
  end

  def grid_at(level)
    if level <= @level_max && level >= @level_min
      @grids[level + @level0]
    end
  end

  def view_port(delta = 0)
    g = grid(delta)
    if g
      g.quick_window(@window_left, @window_top, 0, @window_width, @window_height, 4, true, false) do |v, x, y, z|
        yield v, x, y, z
      end
    end
  end

  def move(n)
    @selected = [ [ selected + n, @level_min ].max, @level_max ].min
  end

  def move_up
    move(1)
    grid.refresh_tiles
  end

  def move_down
    move(-1)
    grid.refresh_tiles
  end

  def to_s
    if @comment.nil? || @comment.empty?
      @name
    else
      "#{@name} (#{@comment})"
    end
  end

  def refresh
    @grids.each do |g|
      g.refresh_tiles
    end
  end

  def used_range
    minx = miny = minl = 99999
    maxx = maxy = maxl = 0
    self.each_with_level do |g, l|
      ux, uy = g.used_range
      if ux.begin < ux.end
        minl, maxl = [ minl, l      ].min, [ maxl, l      ].max
        miny, maxy = [ miny, uy.min ].min, [ maxy, uy.max ].max
        minx, maxx = [ minx, ux.min ].min, [ maxx, ux.max ].max
      end
    end
    [ (minl..maxl), (minx..maxx), (miny..maxy) ]
  end

  # @param sel [Selection,PartialGridStack]
  # @return [GridStack]
  def extract_from_selection(sel)
    if sel.respond_to? :selection_area
      extract(*sel.selection_area)
    elsif sel.respond_to? :coordinates
      extract(*sel.coordinates)
    end
  end

  # @return [GridStack]
  def extract(l, x, y, n, w, h)
    s = PartialGridStack.new(n, w, h)
    n.times do |i|
      lv = l + i
      g = grid_at(lv)
      s[i] = g.extract(x, y, 0, w, h, 3) if g
    end
    s.position = [ l, x, y ]
    s
  end

  # @return [GridStack]
  def extract_range(rl, rx, ry)
    extract(rl.min, rx.min, ry.min, rl.max - rl.min + 1, rx.max - rx.min + 1, ry.max - ry.min + 1)
  end

  # @param stack [PartialGridStack,GridStack]
  def replace(stack, ol = nil, ox = nil, oy = nil)
    p = (stack.respond_to?(:position) ? stack.position : [ 0, 0, 0 ])
    ol ||= p[0]
    ox ||= p[1]
    oy ||= p[2]
    stack.each_with_index do |g, i|
      dg = grid_at(ol + i)
      if dg
        g.quick_each(false) do |v, x, y, z|
          dg[x + ox, y + oy, z] = (v.nil? ? nil : v.dup)
        end
        dg.set_dirty(ox, oy, 0)
        dg.set_dirty(ox + g.width - 1, oy + g.height - 1, 3)
        dg.refresh_tiles(true)
      end
    end
  end

  # @yieldparam grid [Grid]
  # @yieldparam level [Fixnum]
  def each_with_level
    @grids.each { |g| yield g, g.level }
  end

  # @yieldparam grid [Grid]
  def each
    @grids.each { |g| yield g }
  end

  def size
    @levels * @width * @height * 4
  end
end

class PartialGridStack < GridStack
  attr_accessor :position

  def initialize(*args)
    super
    @position = [ 0 ] * 3
  end

  def coordinates
    @position + [ @levels, @width, @height ]
  end
end