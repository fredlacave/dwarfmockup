#! /usr/local/bin/ruby
# encoding: utf-8

class Tile

  ITEM_COMMANDS = {      'b' => 'b',
                         't' => 't:table',
                         'c' => 'c:chair',
                         'h' => 'h:chest',
                         'n' => 'f:cabinet',
                         'r' => 'r:rack',
                         'a' => 'a:armor',
                         's' => 's',
                         'w' => 'l',
                         'l' => 'Tl',
                         'p' => 'Ts',
                         'm' => 'n',
                         'd' => 'd:door',
                         'g' => 'B',
                         'z' => '!B',
                         'f' => 'x',
                         'y' => 'H',
                         'u' => 'Cu',
                         'j' => 'Cd',
                         'o' => 'Cx',
  }

  DIG_COMMANDS = {       '#' => '~',
                         '@' => '~',
                         '.' => 'd',
                         'v' => 'h',
                         '_' => 'h',
                         'r' => 'r',
                         'j' => 'j',
                         'u' => 'u',
                         'i' => 'i',
  }

  DIG_ALT_COMMANDS = {   's' => 's',
                         'e' => 'e',
                         'q' => 'a',
                         't' => '~',
                         'r' => '~',
  }

  DIG_BUILD_COMMANDS = { 'W' => 'Cw',
                         'F' => 'Cf',
                         'A' => 'CF',
  }

  DIG_REVERSE_COMMANDS       = DIG_COMMANDS.invert
  DIG_ALT_REVERSE_COMMANDS   = DIG_ALT_COMMANDS.invert
  DIG_BUILD_REVERSE_COMMANDS = DIG_BUILD_COMMANDS.invert
  ITEM_REVERSE_COMMANDS      = ITEM_COMMANDS.inject({}) { |h, kv| k = kv[0] ; v = kv[1]; v.gsub!(/:.*$/, '') ; h[v] = k ; h }

  attr_accessor :type
  attr_reader :tile, :forecolor, :backcolor

  class << self
    attr_accessor :ih, :iw, :walls1, :items, :others

    def load_tiles(prefs)
      @iw = prefs[:tile_size]
      @ih = prefs[:tile_size]

      # WALL :
      # 0b10100000
      #   TBLRtblr
      @walls1 = {}
      [ 0b1000, 0b0100, 0b0010, 0b0001 ].each_with_index { |e, i| @walls1[e] = prefs[:tiles][:walls_end][i]                   }
      [ 0b1100, 0b0011 ]                .each_with_index { |e, i| @walls1[e] = prefs[:tiles][:walls_straight][i]              }
      [ 0b1010, 0b1001, 0b0110, 0b0101 ].each_with_index { |e, i| @walls1[e] = prefs[:tiles][:walls_curve][i]                 }
      [ 0b1110, 0b1101, 0b1011, 0b0111 ].each_with_index { |e, i| @walls1[e] = prefs[:tiles][:walls_three_ways][i]            }
      [ 0b1111 ]                        .each_with_index { |e, i| @walls1[e] = [ prefs[:tiles][:walls_four_ways] ].flatten[i] }
      [ 0b0000 ]                        .each_with_index { |e, i| @walls1[e] = [ prefs[:tiles][:walls_four_ways] ].flatten[i] }

      @items = { 'b' => prefs[:tiles][:bed],
                 't' => prefs[:tiles][:table],
                 'c' => prefs[:tiles][:chair],
                 'h' => prefs[:tiles][:chest],
                 'n' => prefs[:tiles][:cabinet],
                 'r' => prefs[:tiles][:weapon_rack],
                 'a' => prefs[:tiles][:armor_stand],
                 's' => prefs[:tiles][:statue],
                 'w' => prefs[:tiles][:well],
                 'l' => prefs[:tiles][:lever],
                 'p' => prefs[:tiles][:trap],
                 'm' => prefs[:tiles][:coffin],
                 'd' => prefs[:tiles][:door],
                 'g' => prefs[:tiles][:grid],
                 'z' => prefs[:tiles][:horizontal_bars],
                 'f' => prefs[:tiles][:flood_gate],
                 'y' => prefs[:tiles][:hatch],
                 'u' => prefs[:tiles][:up_stair],
                 'j' => prefs[:tiles][:down_stair],
                 'o' => prefs[:tiles][:updown_stair],
      }

      @others = {}
      [ :anchor, :selection, :command,
        :unknown, :hole, :rough_ground, :dirt_ground, :smooth_ground,
        :up_stair, :down_stair, :updown_stair,
        :up_ramp, :down_ramp,
        :rough_wall, :dirt_wall ].each { |k| @others[k] = prefs[:tiles][k] }
      @others[:unknown] += ([ prefs[:tiles][:unknown_empty] ] * 100)
    end
  end

  def initialize(type, tile = nil, forecolor = 0xffffffff, backcolor = nil)
    @type = type
    self.tile = tile if tile
    self.backcolor = backcolor
    self.forecolor = forecolor
    raise "No color for tile" if @forecolor.nil?
  end

  def initialize_copy(source)
    super
    @type = @type.dup
  end

  def to_s
    "#{self.class} - #{@type}"
  end

  def inspect
    to_s
  end

  def tile=(tile)
    @tile = case tile
            when nil     then $main.tiles[@type]
            when Integer then $main.tiles[tile]
            else              tile
            end
  end

  def backcolor=(backcolor)
    @backcolor = case backcolor
                 when Integer then backcolor
                 when nil     then nil
                 else              $main.res.df_color(backcolor)
                 end
  end

  def forecolor=(forecolor)
    @forecolor = case forecolor
                 when Integer then forecolor
                 else              $main.res.df_color(forecolor)
                 end
  end

  def mix_alpha(c, alpha)
    if alpha == 255
      c
    else
      c % 0xff000000 + alpha * 0x1000000
    end
  end

  def render(x, y, z)
    if @backcolor
      $main.port_rectangle(x, y, Tile.iw, Tile.ih, @backcolor, z)
    end
    $main.port_draw(@tile, x, y, z, @forecolor)
  end

  def render_alpha(x, y, z, alpha = 255)
    if @backcolor
      $main.port_rectangle(x, y, Tile.iw, Tile.ih, mix_alpha(@backcolor, alpha), z)
    end
    $main.port_draw(@tile, x, y, z, mix_alpha(@forecolor, alpha))
  end

  def render_grid(x, y, z, delta = 0)
    px = x * Tile.iw + delta
    py = y * Tile.ih + delta
    if @backcolor
      $main.port_rectangle(px, py, Tile.iw, Tile.ih, @backcolor, z)
    end
    $main.port_draw(@tile, px, py, z, @forecolor)
  end

  def render_grid_alpha(x, y, z, delta = 0, alpha = 255)
    px = x * Tile.iw + delta
    py = y * Tile.ih + delta
    if @backcolor
      $main.port_rectangle(px, py, Tile.iw, Tile.ih, mix_alpha(@backcolor, alpha), z)
    end
    $main.port_draw(@tile, px, py, z, mix_alpha(@forecolor, alpha))
  end

  def unknown?
    false
  end

  def known?
    !unknown?
  end

  def feature?
    true
  end
end

class ItemTile < Tile
  def initialize(type, forecolor = :white)
    super(type, Tile.items[type], forecolor, :black)
  end

  def type=(v)
    super
    self.tile = Tile.items[@type]
  end

  def command(state)
    (state == :build ? ITEM_COMMANDS[@type] : '~')
  end

  def reverse_command(state, command)
    if state == :build
      c = command.sub(/:.*$/, '')
      if ITEM_REVERSE_COMMANDS.has_key? c
        self.type = ITEM_REVERSE_COMMANDS[c]
      end
    end
  end
end

class CommandTile < Tile
  def initialize(type, forecolor = nil, backcolor = nil)
    forecolor ||= (type[0, 1] == 's' ? 0x8000ff00 : 0x80ffff00)
    super(type, Tile.others[:command], forecolor, backcolor) # 88 = X
  end

  def command(state)
    (@type[0, 1] == state.to_s[0, 1] ? @type[2..-1] : '~')
  end

  def reverse_command(state, command)
    @type = state.to_s[0, 1] + '-' + command
  end

  def type=(v)
    # @forecolor = (v[0, 1] == 's' ? 0x8000ff00 : 0x80ffff00)
    @type = v
  end

  def feature?
    false
  end
end

class GroundTile < Tile
  def initialize(type, forecolor = :white, backcolor = nil)
    @unknown_index = Tile.others[:unknown].sample
    if type == nil
      @forecolor = forecolor
      @backcolor = backcolor
      @type = '@r'
      @tile_index = @unknown_index
      @tile = $main.tiles[@tile_index]
    else
      super(type, 0, forecolor, backcolor)
      @unkown_index = nil
      @tile_index = nil
      set_tile
    end
    @rand = rand(32000)
  end

  def space_type
    @type[0, 1]
  end

  def space_type=(v)
    @type[0, 1] = v
  end

  def finish
    @type[1, 1]
  end

  def finish=(v)
    @type[1, 1] = v
  end

  def tile=(v)
    @tile_index = v if v.is_a? Fixnum
    super
  end

  def unknown?      ; space_type == '@' ; end
  def accessible?   ; space_type != '@' && space_type != '#' ; end
  def unaccessible? ; space_type == '@' || space_type == '#' ; end
  def ground?       ; space_type == '.' ; end
  def wall?         ; space_type == '#' || finish     == 'W' || finish     == 'A' ; end
  def hole?         ; space_type == '_' || space_type == 'v' ; end
  def up_ramp?      ; space_type == 'r' ; end
  def stair?        ; space_type == 'j' || space_type == 'i' || space_type == 'u' ; end
  def down_stair?   ; space_type == 'j' ; end
  def updown_stair? ; space_type == 'i' ; end
  def up_stair?     ; space_type == 'u' ; end
  def dirt?         ; finish     == 'd' ; end
  def rough?        ; finish     == 'r' ; end
  def smooth?       ; finish     == 's' ; end
  def engraved?     ; finish     == 'e' ; end
  def altered?      ; finish     == 's' || finish == 'e'     || finish == 'a'     || finish == 'F'     || finish == 'A'     || finish == 'W'     ; end
  def constructed?  ; finish     == 'A' || finish     == 'W' ; end
  def feature?      ; space_type != '@' && space_type != '.' ; end

  def can_connect_wall?
    altered? && wall?
  end

  def can_end_wall?
    wall? && (altered? || rough? || dirt? || unknown?)
  end

  def set_tile(g = nil)
    if g.is_a? Array
      tc, bc, lc, rc = g[0..3]
    elsif g.is_a? Grid
      tc, bc, lc, rc = g.top_cell, g.bottom_cell, g.left_cell, g.right_cell
    else
      tc, bc, lc, rc = nil, nil, nil, nil
    end

    if @type =~ /^@/
      if g && g.any? { |e, *a| e != self && (e && e.accessible?) }
        update_type('# ')
        @tile_index = nil
      end
    elsif @type =~ /^#/
      if g && g.all? { |e, *a| e != self && (!e || e.unaccessible?) }
        update_type('@r')
        @tile_index = nil
      end
    end

    t = case @type[0, 2]
        when /^@/       then @unknown_index
        when /^_/       then Tile.others[:hole]
        when /^j/       then Tile.others[:down_stair]
        when /^i/       then Tile.others[:updown_stair]
        when /^u/       then Tile.others[:up_stair]
        when /^v/       then Tile.others[:down_ramp]
        when /^r/       then Tile.others[:up_ramp]
        when '.d'       then Tile.others[:dirt_ground]
        when '.r'       then Tile.others[:rough_ground]
        when '.s', '.e', /F$/ then Tile.others[:smooth_ground]
        when '#r'       then Tile.others[:rough_wall]
        when '#d'       then Tile.others[:dirt_wall]
        when '#s', '#e', '#a', /A$/, /W$/ then
          v = 0b0000
          v |= 0b1000 if tc && tc.can_connect_wall?
          v |= 0b0100 if bc && bc.can_connect_wall?
          v |= 0b0010 if lc && lc.can_connect_wall?
          v |= 0b0001 if rc && rc.can_connect_wall?
          Tile.walls1[v]
        else
          225
        end
    if t.is_a? Array
      self.tile = t.sample unless t.include? @tile_index
    elsif t
      self.tile = t
    end
  end

  def update_type(t)
    ns = t[0, 1]
    nf = t[1, 1]
    if nf != ' ' && nf != finish && space_type != '@' && (nf != 'a' || space_type == '#')
      @type[1, 1] = nf
      @forecolor = if finish == 'A'
                     $main.res.df_color(:lred)
                   elsif finish == 'W' || finish == 'F'
                     $main.res.df_color(:white)
                   elsif finish == 'e'
                     $main.res.df_color(:lgray)
                   elsif finish == 'a'
                     $main.res.df_color(:yellow)
                   else
                     $main.res.df_color(:dgray)
                   end
    end
    @type[0, 1] = ns unless ns == ' '
  end

  def command(state)
    case state
    when :dig
      DIG_COMMANDS[space_type]
    when :dig_alt
      DIG_ALT_COMMANDS[finish]
    when :build0
      DIG_BUILD_COMMANDS[finish]
    end || '~'
  end

  def reverse_command(state, command)
    case state
    when :dig
      if DIG_REVERSE_COMMANDS.has_key? command
        update_type DIG_REVERSE_COMMANDS[command] + ' '
      end
    when :dig_alt
      if DIG_ALT_REVERSE_COMMANDS.has_key? command
        update_type ' ' + DIG_ALT_REVERSE_COMMANDS[command]
      end
    when :build0
      if DIG_BUILD_REVERSE_COMMANDS.has_key? command
        update_type ' ' + DIG_BUILD_REVERSE_COMMANDS[command]
      end
    end
  end
end
