#! /usr/local/bin/ruby
# encoding: utf-8

require_relative "tile"
require_relative "shape"

class Selection
  MODE_MAP = { 'r' => :rectangle, 'e' => :ellipse, 'z' => :ellipse_c, 'c' => :rectangle_c, 'o' => :one, 'l' => :line }
  MODE_RMAP = MODE_MAP.inject({}) { |h, e| h[e[1]] = e[0] ; h }

  attr_accessor :x, :ax, :dx
  attr_accessor :y, :ay, :dy
  attr_accessor :l, :al, :dl
  attr_accessor :mode, :moved

  def initialize(width, height, tiles)
    @width = width
    @height = height
    @x,  @y,  @l  = 0, 0, 0
    @dx, @dy, @dl = 0, 0, 0
    @ax, @ay, @al = nil, nil, nil
    @moved = true
    @prefs = Preferences.instance
    @ts =  @prefs[:tile_size]

    @cur_tile  = Tile.new(-1, tiles[@prefs[:tiles][:cursor]],    :yellow, :black)
    @anc_tile  = Tile.new(-2, tiles[@prefs[:tiles][:anchor]],    :green, :black)
    @sel_tile  = Tile.new(-3, tiles[@prefs[:tiles][:selection]], :brown)
    @cnt_tile  = Tile.new(-1, tiles[@prefs[:tiles][:cursor]],    :green, :black)
    @up_tile   = Tile.new(-1, tiles[@prefs[:tiles][:up_ramp]],   :green, :black)
    @down_tile = Tile.new(-1, tiles[@prefs[:tiles][:down_ramp]], :green, :black)

    @mode = :rectangle

    @tiles_count = 0
    @tick = 0

    @cross = false
  end

  def goto(x, y)
    @x = x
    @y = y
    @moved = true
  end

  def moved?
    @moved
  end

  def set_moved
    @moved = true
  end

  def reset_moved
    @moved = false
  end

  def increase_motion(dx, dy)
    @dx = dx if dx != 0
    @dy = dy if dy != 0
  end

  def reset_motion(dx, dy)
    @dx = 0 if dx != 0
    @dy = 0 if dy != 0
  end

  def drift(fast = false)
    s = (fast ? 10 : 1)
    if @dx != 0
      @x = [ [ 1, @x + (@dx < 0 ? -s : s) ].max, @width - 2 ].min
      @moved = true
    end
    if @dy != 0
      @y = [ [ 1, @y + (@dy < 0 ? -s : s) ].max, @height - 2 ].min
      @moved = true
    end
  end

  def l=(v)
    @l = v
    @moved = true
  end

  def immobile?
    @dx == 0 && @dy == 0
  end

  def stop
    @dx = @dy = 0
  end

  def selecting?
    !@ax.nil?
  end

  def clear_selection
    @ax = @ay = @al = nil
    @moved = true
    stop
  end

  def start_selection
    @ax, @ay, @al = @x, @y, @l
    @moved = true
  end

  def selection_area
    if @ax
      [
          [ @l, @al ].min, [ @x, @ax ].min, [ @y, @ay ].min,
          (@l - @al).abs + 1, (@x - @ax).abs + 1, (@y - @ay).abs + 1
      ]
    else
      [ @l, @x, @y, 1, 1, 1]
    end
  end

  def mode=(v)
    case v
    when String
      @mode = MODE_MAP(v) if MODE_MAP.has_key?(v)
    when Symbol
      @mode = v if MODE_MAP.values.find { |m| m == mode }
    end
  end

  def complex_mode
    (@mode == :line && ((@ax < @x && @ay > @y) || (@ay < @y && @ax > @x)) ? :line_inv : @mode)
  end

  def dirty_grid(stack, margin)
    l, x, y, n, w, h = selection_area
    n.times do |dl|
      stack.grid_at(l + dl).set_dirty(x - margin, y - margin, 0)
      stack.grid_at(l + dl).set_dirty(x + w + margin * 2, y + h + margin * 2, 0)
    end
  end

  def apply_to(stack, z, &block)
    l, x, y, n, w, h = selection_area
    n.times do |dl|
      grid = stack.grid_at(l + dl)
      Shape.shape(x, y, z, w, h, 1, complex_mode) do |sx, sy, sz|
        grid.yield_dirty grid[sx, sy, sz], sx, sy, sz, &block
      end
    end
  end

  def update
    @tick = (@tick + 1) % 60
  end

  def draw(gcx = nil, gcy = nil)
    if @ax
      if @mode == :ellipse
        cx = (@x - @ax).abs / 2.0 + (@ax < @x ? @ax : @x)
        cy = (@y - @ay).abs / 2.0 + (@ay < @y ? @ay : @y)
      end
      if @tick % 10 < 5 || @moved
        @tiles_count = 0
        Shape.shape_xy(@x, @y, 0, @ax, @ay, 1, complex_mode, true) do |x, y, z, c|
          if c
            @sel_tile.render_grid(x, y, 98)
            @tiles_count += 1
          else
            @sel_tile.render_grid_alpha(x, y, 98, 0, 0x66)
          end
        end
        if @mode == :ellipse
          cx = (@x - @ax).abs / 2.0 + (@ax < @x ? @ax : @x)
          cy = (@y - @ay).abs / 2.0 + (@ay < @y ? @ay : @y)
          @anc_tile.render_grid(cx.round, cy.round, 98)
        end
        [ @up_tile, @anc_tile, @down_tile ][(@l <=> @al) + 1].render_grid(@ax, @ay, 99)
      end
    else
      @sel_count = 1
    end
    if @tick % 40 < 20 && gcx && gcy
      @cnt_tile.render_grid(gcx, gcy, 99)
    end
    @cur_tile.render_grid(@x, @y, 100)
    if @cross
      draw_cross(@x,  @y,  0xff444444, 99)
      draw_cross(@ax, @ay, 0xff444444, 99) if @ax
      draw_cross(cx,  cy,  0xff444444, 99) if @mode == :ellipse && cx
    end
  end

  def draw_cross(x, y, color, level)
    $main.port_cross(x * @ts + @ts / 2, y * @ts + @ts / 2, 0, 0, @width * @ts - 1, @height * @ts - 1, color, level)
  end

  def legend
    if @ax
      "P: (%3d,%3d,%+1d)\nS: (%3d,%3d,%+1d) -- C: %4d" % [ @x, @y, @l, @ax, @ay, @al, @tiles_count * ((@l - @al).abs + 1)  ]
    else
      "P: (%3d,%3d,%+1d)" % [ @x, @y, @l ]
    end
  end

  def set_mode(mode)
    if MODE_MAP.has_key?(mode)
      @mode = MODE_MAP[mode]
      true
    else
      false
    end
  end

  def mode_s
    MODE_RMAP[@mode] || 'r'
  end

  def toggle_cross_hair
    @cross = !@cross
  end
end