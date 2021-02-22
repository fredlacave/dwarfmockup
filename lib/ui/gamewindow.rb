#! /usr/local/bin/ruby
# encoding: utf-8

require_relative '../grids/selection'
require_relative '../grids/blueprint'
require_relative '../grids/gridstack'

require_relative '../misc/preferences'
require_relative '../misc/resource'

require_relative '../ui/dialogchains'
require_relative '../ui/textscrollbox'
require_relative '../ui/waitdialog'

class GameWindow < Gosu::Window
  attr_accessor :tiles, :res, :blueprint, :ts, :ww, :wh, :saved, :copy

  def initialize(prefs)
    @prefs = prefs

    super([ @prefs[:window_width], Gosu::available_width ].min, [ @prefs[:window_height], Gosu::available_height ].min, @prefs[:fullscreen])
    @caption = "Dwarf Mockup"
    @rcaption = @caption
    self.caption = @caption

    @ts = @prefs[:tile_size]

    reinit
  end

  def reinit
    @ghost = nil
    @delta_grid = 0

    @last_key = nil
    @first_key = nil
    @key_code = nil

    @main_mode = :design
    @mode = 'd'
    @protect = false

    @copy = nil
    @undo = []
    @redo = []
    @saved = true

    set_input nil
  end

  def grid
    @blueprint.stack.grid
  end

  # @return [GridStack]
  def stack
    @blueprint.stack
  end

  def setup
    Tile.load_tiles(@prefs)

    @res = Resource.instance
    @res.setup(File.expand_path(File.join(APP_PATH, 'res')))
    @font = @res.default_font

    @tiles = @res.default_tiles

    @ghost = @prefs[:ghost] ? 1 : nil

    @sel = Selection.new(NT, NT, @tiles)
    @sel.toggle_cross_hair if @prefs[:crosshairs]

    @sep_l = (self.width - @font.text_width(HELP[:design].first)).to_i - 1
    @ww = (@sep_l / @ts).to_i
    @wh = (self.height / @ts).to_i

    @dx_pix = 0
    @dy_pix = 0
    @dw_pix = ww * @ts - 1
    @dh_pix = wh * @ts - 1

    setup_grid

    @sel.l = @blueprint.stack.selected

    reset_fps

    nil
  end

  def setup_grid
    @blueprint = Blueprint.new('NewFile')
    @sel.goto(stack.cx, stack.cy)
    @dx_pix = stack.window_left * @prefs[:tile_size]
    @dy_pix = stack.window_top * @prefs[:tile_size]
  end

  def reset_fps
    @last_milli = Gosu::milliseconds()
    @last_fps = @fps || 0
    @fps = 0
  end

  def needs_cursor?
    true
  end

  def button_down(b)
    if @input.nil?
      f = false
      CKEYS.each_with_index do |lk, i|
        if lk.find { |k| k == b }
          @first_key ||= Gosu::milliseconds
          @sel.increase_motion(*DIRS[i])
          f = true
        end
      end
      unless f
        if b == Gosu::KbInsert || b == Gosu::KbNumpadMultiply
          @delta_grid = 1
        elsif b == Gosu::KbDelete || b == Gosu::KbNumpadDivide
          @delta_grid = -1
        end
      end
    end
  end

  def button_up(b)
    f = false
    if @input.nil?
      CKEYS.each_with_index do |lk, i|
        if lk.find { |k| k == b }
          @sel.reset_motion(*DIRS[i])
          f = true
        end
      end
    end
    if !f && !DKEYS.include?(b)
      shift =   (button_down?(Gosu::Button::KbLeftShift   )  ||
                 button_down?(Gosu::Button::KbRightShift  ))
      alt =     (button_down?(Gosu::Button::KbLeftAlt     )  ||
                 button_down?(Gosu::Button::KbRightAlt    ))
      control = (button_down?(Gosu::Button::KbLeftControl )  ||
                 button_down?(Gosu::Button::KbRightControl))
      @key_code = [ b, shift, alt, control ]
      update if control || shift || alt
    end
    @first_key = @last_key = nil if @sel.immobile?
    if b == Gosu::KbInsert || b == Gosu::KbDelete || b == Gosu::KbNumpadMultiply || b == Gosu::KbNumpadDivide
      @delta_grid = 0
    end
  end

  def update
    @sel.update

    key_code = nil
    key = nil
    if @key_code
      key = button_id_to_char(@key_code[0])
      key_code, shift, alt, control = @key_code
    end
    if key.nil? || key.to_i > 0
      shift = (button_down?(Gosu::Button::KbLeftShift   )  ||
               button_down?(Gosu::Button::KbRightShift  ))
    end
    if @input
      if key_code == Gosu::MsLeft
        @input.click
      else
        @input.key_press(key_code) if key_code
      end
      @key_code = nil
    else
      if @first_key
        d = Gosu::milliseconds
        if @last_key.nil? || (d - @first_key > KEY_REPEAT && d - @last_key > KEY_PRESS)
          @sel.drift(shift)
          stack.adjust_view_port(@sel)
          @dx_pix = stack.window_left * @ts
          @dy_pix = stack.window_top * @ts
          @last_key = d
        end
      end
      if key_code
        if key_code == Gosu::Button::KbPageUp || key_code == Gosu::Button::KbNumpadAdd || key_code == Gosu::Button::KbComma
          stack.move_up
          @sel.l = stack.selected
        elsif key_code == Gosu::Button::KbPageDown || key_code == Gosu::Button::KbNumpadSubtract || key_code == Gosu::Button::KbPeriod
          stack.move_down
          @sel.l = stack.selected
        elsif key_code == Gosu::Button::KbReturn || key_code == Gosu::Button::KbEnter
          if !@sel.selecting? && @sel.mode != :one
            @sel.start_selection
          else
            send(:"handle_#{@main_mode}")
            @sel.clear_selection
          end
          @key_code = nil
        elsif key_code == Gosu::Button::KbEscape
          send(:"cancel_#{@main_mode}") if respond_to?(:"cancel_#{@main_mode}")
          @sel.clear_selection
        elsif shift && !alt && !control
          unless @sel.set_mode(key)
            case key
            when 'g'
              @ghost = (@ghost ? nil : 1)
            when 'x'
              stack.cx = @sel.x
              stack.cy = @sel.y
            when 'h'
              @sel.toggle_cross_hair
            when 'm', 'n'
              @main_mode = MAIN_MODES[(MAIN_MODES.index(@main_mode) + (key == 'm' ? 1 : -1)) % MAIN_MODES.length]
              @sel.mode = (@main_mode == :design ? :rectangle : :one)
              @mode = (@main_mode == :design || @main_mode == :items ? 'd' : 'p')
              @key_code = nil
            when 'p'
              @protect = !@protect
            when 'w'
              stack.show_center = !stack.show_center
            end
          end
        elsif control && !shift && !alt
          case key
          when 'z'
            do_undo
          when 'y'
            do_redo
          when 'q'
            QuitChain.new(self)
          when 's'
            SaveChain.new(self)
          when 'l'
            LoadChain.new(self)
          when 'n'
            NewChain.new(self)
          when 'a'
            TextScrollBox.new(self, 'About DwarfMockup v' + DWARFMOCKUP_VERSION, File.read('res/LICENSE'), { :ok => 'OK' })
          when 'h'
            TextScrollBox.new(self, 'Help & keybindings', File.read('res/HELP'), { :ok => 'OK' })
          when 'c'
            do_copy
          when 'v'
            do_paste
          when 'x'
            do_copy(true)
          end
        elsif control && shift && !alt
          case key
          when 'l'
            store_undo
            AltLoadChain.new(self)
          end
        else
          @mode = key if MODE[@main_mode].include? key
        end
        @key_code = nil
      end
    end
  end

  def do_copy(cut = false)
    store_undo if cut
    @old_main_mode = @main_mode
    @main_mode = (cut ? :cut : :copy)
    @sel.start_selection
  end

  def cancel_copy
    @main_mode = @old_main_mode
  end

  def cancel_cut
    @main_mode = @old_main_mode
  end

  def full_mode
    "#{@main_mode}-#{@mode}-#{@sel.mode}"
  end

  def store_undo
    @undo << stack.extract_from_selection(@sel)
    nt = @undo.inject(0) { |m, g| m += g.size }
    while nt > 10_000
      break if @undo.length == 1
      nt -= @undo.shift.size
    end
    @redo.clear
    @saved = false
    nil
  end

  def do_undo
    unless @undo.empty?
      u = @undo.pop
      @redo << stack.extract_from_selection(u)
      stack.replace(u)
    end
  end

  def do_redo
    unless @redo.empty?
      r = @redo.pop
      @undo << stack.extract_from_selection(r)
      stack.replace(r)
    end
  end

  def handle_copy
    @copy = stack.extract_from_selection(@sel)
    @main_mode = @old_main_mode
  end

  def handle_cut
    @copy = stack.extract_from_selection(@sel)
    handle_design('w')
    @main_mode = @old_main_mode
  end

  def do_paste
    if @copy
      store_undo
      stack.replace(@copy, @sel.l, @sel.x, @sel.y)
    end
  end

  def handle_design(mode = @mode)
    if (op = MODE_TO_OPERATION[mode])
      store_undo
      pm = @protect ? PROTECT_MODE[mode] : nil
      @sel.apply_to(stack, 0) do |v, sx, sy, sz|
        v.update_type(op) if v && (!pm || pm.include?(v.type[0..0]))
      end
    end
    stack.grid.refresh_tiles(op[0, 1] == '#')
  end

  def handle_items
    store_undo
    @sel.apply_to(stack, 1) do |v, sx, sy, sz|
      if @mode == 'x'
        grid[sx, sy, sz] = nil
      else
        if v
          v.type = @mode
        else
          grid[sx, sy, sz] = ItemTile.new(@mode)
        end
      end
    end
  end

  def handle_stockpiles
    prepare_handle_command(2)
  end

  def handle_adjustments
    prepare_handle_command(3)
  end

  def prepare_handle_command(z)
    orig_sel = @sel.dup
    if @mode == 'x'
      handle_command(z, nil, false, orig_sel)
    else
      what = nil
      @sel.apply_to(stack, z) do |v, sx, sy, sz|
        unless v.nil?
          what = v.type[2..-1]
          break
        end
      end
      what ||= ''
      InputBox.new(self, 'Command to send :', what) { |what, cancel| handle_command(z, what, cancel, orig_sel) }
    end
  end

  def handle_command(z, what, cancel, orig_sel)
    return if cancel
    store_undo
    orig_sel.apply_to(stack, z) do |v, sx, sy, sz|
      if @mode == 'x'
        grid[sx, sy, sz] = nil
      else
        if v
          v.type = what
        else
          grid[sx, sy, sz] = CommandTile.new(@main_mode.to_s[0, 1] + '-' + what)
        end
      end
    end
  end

  def set_input(dialog)
    self.text_input = dialog
    @input = dialog
  end

  def draw
    draw_layout
    if stack
      draw_grids
      draw_selection
    end
    update_caption
    draw_legend
    @input.draw if @input
  end

  def draw_layout
    draw_line(@sep_l,     0, 0xffffffff, @sep_l,     height, 0xffffffff, 0)
    draw_line(@sep_l + 2, 0, 0xffffffff, @sep_l + 2, height, 0xffffffff, 0)
  end

  def draw_grids
    stack.view_port(@delta_grid) do |v, x, y, z|
      v.render_grid(x, y, z)
    end
    if @ghost && @delta_grid == 0
      (-@ghost).upto(@ghost) do |d|
        next if d == 0
        stack.view_port(d) do |v, x, y, z|
          v.render_grid_alpha(x, y, z + 1, -4 * d, 96) if v.feature?
        end
      end
    end
  end

  def draw_selection
    if stack.show_center
      @sel.draw(stack.cx, stack.cy)
    else
      @sel.draw
    end
  end

  def draw_legend
    @legend = nil if @last_mode != [ full_mode, @protect ]
    if @legend.nil?
      nl = [ 0, ((self.height - (HELP[@main_mode].length + SEL_HELP.length + 4) * @ts) / @ts).to_i ].max
      t = HELP[@main_mode] + [ '' ] * nl + SEL_HELP
      @ml = t.index { |l| l =~ /^\s*#{@mode} :/ }
      @sl = t.index { |l| l =~ /^\s*#{@sel.mode_s.upcase} :/ }
      @pl = (@protect ? t.index { |l| l =~ /^\s*P :/ } : nil)
      @legend = Gosu::Image.from_text(self, t.join("\n"), @font.name, @ts, 0, self.width - @sep_l - 6, :left)
      @last_mode = [ full_mode, @protect ]
    end
    @legend.draw(@sep_l + 8, 0, -2)

    rectangle(@sep_l + 4, @ml * @ts, self.width - @sep_l - 4, @ts, 0xaaffffff, -1) if @ml
    rectangle(@sep_l + 4, @sl * @ts, self.width - @sep_l - 4, @ts, 0xaaffffff, -1) if @sl
    rectangle(@sep_l + 4, @pl * @ts, self.width - @sep_l - 4, @ts, 0xaaffffff, -1) if @pl

    if stack
      @grid_legend = nil if @sel.moved
      if @grid_legend.nil?
        @sel.moved = false
        @grid_legend = Gosu::Image.from_text(self, @sel.legend, @font.name, @ts, 0, self.width - @sep_l - 8, :left)
      end

      @grid_legend.draw(@sep_l + 8, self.height - @ts * 2 - 2, -2)

      if fullscreen?
        @font.draw(caption, @sep_l + 8, self.height - @ts * 3, 1000, 1, 1, 0xffffffff)
      end
    end
  end

  # Quick and dirty - only takes into account the top left pixel
  def port_draw(image, x, y, z, c)
    px, py = x - @dx_pix, y - @dy_pix
    if px >= 0 && py >= 0 && px <= @dw_pix && py <= @dh_pix
      image.draw(px, py, z, 1, 1, c)
    end
  end

  # Quick and dirty too
  def port_rectangle(x, y, w, h, c, z)
    px, py = x - @dx_pix, y - @dy_pix
    pw = ([ px + w, @dw_pix ].min) - px
    if px >= 0 && py >= 0 && px < @dw_pix && py < @dh_pix
      rectangle(px, py, pw, h, c, z)
    end
  end

  # Same ; only checks the right margin
  def port_cross(x, y, l, t, w, h, c, z)
    px, py = x - @dx_pix, y - @dy_pix
    pl, pt = l - @dw_pix, t - @dy_pix
    pw = [ w, @dw_pix ].min
    draw_cross(px, py, pl, pt, pw, h, c, z)
  end


  # Same ; only checks the right margin
  def port_line(x1, y1, x2, y2, c, z)
    px1, py1 = x1 - @dx_pix, y1 - @dy_pix
    px2, py2 = [ x2 - @dx_pix, @dw_pix - 1 ].min, [ y2 - @dy_pix, @dy_pix - 1 ].min
    if px1 >= 0 && py1 >= 0 && px2 < @dw_pix && py2 < @dh_pix
      draw_line(px1, py1, c, px2, py2, c, z)
    end
  end

  def update_caption
    @fps += 1
    if Gosu::milliseconds - @last_milli > 1000 || Gosu::milliseconds < @last_milli
      @rcaption = "#{@caption} - #{@blueprint.name} - (#{@last_fps} FPS)"
      self.caption = "#{@caption} - #{@blueprint.name} - (#{@last_fps} FPS)"
      reset_fps
    end
  end
end

# Kb0, Kb1, ...
# KbA, KbB, ...
# KbF1, KbF2, ...
# KbNumpad0, KbNumpad1, ...
# KbNumpadAdd, KbNumpadDivide, KbNumpadMultiply, KbNumpadSubtract

# KbSpace, KbTab, KbReturn, KbEnter, KbEscape

# KbLeftAlt, KbLeftControl, KbLeftMeta, KbLeftShift
# KbRightAlt, KbRightControl, KbRightMeta, KbRightShift

# KbHome, KbEnd, KbInsert, KbBackspace, KbDelete, KbPageDown, KbPageUp, KbRangeBegin, KbRangeEnd, KbNum
# KbDown, KbLeft, KbRight, KbUp
