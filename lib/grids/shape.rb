#! /usr/local/bin/ruby
# encoding: utf-8

require "narray"

require_relative "tile"

module Shape
  def set_range(a)
    if a.is_a? Fixnum
      a..a
    elsif a.is_a? Range
      ([ a.min, 0 ].max)..([ a.max, NT - 1 ].min)
    elsif a.respond_to?(:first) && a.respond_to?(:last)
      a.first..a.last
    elsif a.respond_to?(:min) && a.respond_to?(:max)
      a.min..a.max
    else
      raise "Invalid argument : #{args.inspect}"
    end
  end

  def window(x, y, z, w, h, d, &block)
    z.upto(z + d - 1) do |sz|
      y.upto(y + h - 1) do |sy|
        x.upto(x + w - 1) do |sx|
          block.call(sx, sy, sz)
        end
      end
    end
  end

  def empty_window(x, y, z, w, h, d, &block)
    z.upto(z + d - 1) do |sz|
      y.upto(y + h - 1) do |sy|
        block.call(x, sy, sz)
        block.call(x + w - 1, sy, sz)
      end
      (x + 1).upto(x + w - 2) do |sx|
        block.call(sx, y, sz)
        block.call(sx, y + h - 1, sz)
      end
    end
  end

  def window_range(rx, ry, rz, &block)
    rx = set_range(rx)
    ry = set_range(ry)
    rz = set_range(rz)
    window(rx.min, ry.min, rz.min, rx.max - rx.min + 1, ry.max - ry.min + 1, rz.max - rz.min + 1, &block)
  end

  def empty_window_range(rx, ry, rz, &block)
    rx = set_range(rx)
    ry = set_range(ry)
    rz = set_range(rz)
    empty_window(rx.min, ry.min, rz.min, rx.max - rx.min + 1, ry.max - ry.min + 1, rz.max - rz.min + 1, &block)
  end

  def shape_array(w, h, shape, contour = false)
    sa = NArray.byte(w + 2, h + 2)
    cx = ((w - 1) / 2.0) + 1
    cy = ((h - 1) / 2.0) + 1

    if contour
      blip = lambda do |x, y|
        sa[x, y] |= 2
        empty_window(x - 1, y - 1, 0, 3, 3, 1) do |dx, dy, dz|
          sa[dx, dy] |= 1
        end
      end
    else
      blip = lambda do |x, y|
        sa[x, y] |= 2
      end
    end

    shape = :one if w == 1 && h == 1

    case shape
    when :one
      blip.call(1, 1)

    when :line, :line_inv
      dx = 1
      dy = shape == :line ? 1 : h
      ty = shape == :line ? h : 1
      sy = shape == :line ? 1 : -1
      fh = h > w
      e =  w - h
      loop do
        blip.call(dx, dy)
        break if dx == w && dy == ty
        e2 = e * 2
        if e2 >= -h + 1
          e += -h + 1
          dx += 1
          if fh
            blip.call(dx, dy)
          end
        end
        if e2 <= w - 1
          e += w - 1
          dy += sy
          if !fh
            blip.call(dx - 1, dy)
          end
        end
      end

    when :ellipse_c
      quad_blip = lambda do |x0, y0, x1, y1|
        [ [x1, y0], [x0, y0], [x1, y1], [x0, y1] ].each do |x, y|
          blip.call(x, y)
        end
      end
      dx, dy = 1, 1
      tx = w
      b1 = (h - 1) % 2
      ex = 4 * (2 - w) * (h - 1) * (h - 1)
      ey = 4 * (b1 + 1) * (w - 1) * (w - 1)
      e = ex + ey + b1 * (w - 1) * (w - 1)
      dy = dy + (h  / 2)
      ty = dy - b1
      a1 = 8 * (w - 1) * (w - 1)
      b1 = 8 * (h - 1) * (h - 1)

      loop do
        quad_blip.call(dx, dy, tx, ty)
        e2 = 2 * e
        if e2 <= ey
          dy += 1
          ty -= 1
          quad_blip.call(dx, dy, tx, ty)
          ey += a1
          e += ey
        end
        if e2 >= ex || 2 * e > ey
          dx += 1
          tx -= 1
          ex += b1
          e += ex
        end
        break unless dx <= tx
      end

      loop do
        break unless dy - ty <= h - 1
        quad_blip.call(dx - 1, dy, tx + 1, ty)
        dy += 1
        ty -= 1
      end

    when :rectangle_c
      empty_window(1, 1, 0, w, h, 1) do |dx, dy, dz|
        blip.call(dx, dy)
      end

    when :rectangle
      if contour
        empty_window(1, 1, 0, w, h, 1) do |dx, dy, dz|
          blip.call(dx, dy)
        end
        window(2, 2, 0, w - 2, h - 2, 1) do |sx, sy, sz|
          sa[sx, sy] |= 2
        end
      else
        window(1, 1, 0, w, h, 1) do |sx, sy, sz|
          sa[sx, sy] |= 2
        end
      end

    when :ellipse
      window(0, 0, 0, w + 1, h + 1, 1) do |sx, sy, sz|
        if sx > 0 && sy > 0 && sx <= w && sy <= h &&
           (((sx - cx) ** 2).to_f / ((w / 2.0) ** 2) + \
           ((sy - cy) ** 2).to_f / ((h / 2.0) ** 2) < 1.0)
          blip.call(sx, sy)
        end
      end

    else
      raise "Invalid shape : #{shape.inspect}"
    end
    sa
  end

  def shape(x, y, z, w, h, d, shape, contour = false, &block)
    shape = :line_inv if shape == :line && ((w < 0 && h > 0) || (h < 0 && w > 0))
    a = shape_array(w, h, shape, contour)
    if block.arity == 3
      window(1, 1, 0, w, h, 1) do |sx, sy, sz|
        dx = sx + x - 1
        dy = sy + y - 1
        block.call(dx, dy, z) if a[sx, sy]  > 1
      end
    else
      window(0, 0, 0, w + 2, h + 2, 1) do |sx, sy, sz|
        dx = sx + x - 1
        dy = sy + y - 1
        block.call(dx, dy, z, false) if a[sx, sy] == 1
        block.call(dx, dy, z, true) if a[sx, sy]  > 1
      end
    end
  end

  def shape_xy(x1, y1, z1, x2, y2, z2, shape, contour = false, &block)
    x1, x2 = [ x1, x2 ].sort
    y1, y2 = [ y1, y2 ].sort
    z1, z2 = [ z1, z2 ].sort
    shape(x1, y1, z1, x2 - x1 + 1, y2 - y1 + 1, z2 - z1 + 1, shape, contour, &block)
  end

  def rectangle(x, y, z, w, h, d, full = true, &block)
    window(x, y, z, w, h, d) do |sx, sy, sz|
      block.call(sx, sy, sz) if(full || sx == x || sx == x + h - 1 || sy == y || sy == y + w - 1)
    end
  end

  def rectangle_xy(x1, y1, z1, x2, y2, z2, full = true, &block)
    x1, x2 = [ x1, x2 ].sort
    y1, y2 = [ y1, y2 ].sort
    z1, z2 = [ z1, z2 ].sort
    rectangle(x1, y1, z, x2 - x1 + 1, y2 - y1 + 1, z2 - z1 + 1, full, &block)
  end

  module_function :window, :window_range, :empty_window, :empty_window_range
  module_function :shape, :shape_xy, :rectangle, :rectangle_xy, :set_range, :shape_array
end
