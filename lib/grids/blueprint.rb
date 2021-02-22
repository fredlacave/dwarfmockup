#! /usr/local/bin/ruby
# encoding: utf-8

require_relative 'gridstack'

class Blueprint
  PHASES = [ :dig, :dig_alt, :build0, :build, :stockpile, :adjust ]
  PHASES_RE = Regexp.new("-(?i-:#{PHASES.join('|')})$")
  PHASES_TO_Z =     { :dig       => 0,
                      :dig_alt   => 0,
                      :build0    => 0,
                      :build     => 1,
                      :stockpile => 2,
                      :adjust    => 3 }
  PHASES_COMMANDS = { :dig       => 'dig',
                      :dig_alt   => 'dig',
                      :build0    => 'build',
                      :build     => 'build',
                      :stockpile => 'stockpile',
                      :adjust    => 'query' }

  attr_accessor :cx, :cy, :show_center
  attr_accessor :ox, :oy, :ol
  attr_accessor :multi_step, :native, :valid, :phases

  attr_accessor :file_name, :stack, :name, :comment, :first_file

  def initialize(name = nil, comment = nil, partial = false)
    @name = name
    @comment = comment
    @native = true
    @multi_step = true
    @valid = true
    @complete = true
    @phases = []
    @partial = false

    @cx = 0
    @cy = 0
    @partial = partial
    @stack = GridStack.default unless @partial

    @prefs = Preferences.instance
    init_from_filename(@name)
  end

  # @return [Blueprint]
  def init_from_filename(name)
    @first_file = nil
    @phases = []
    @multi_step = false
    @file_name = File.join(@prefs[:blueprints_dir], name.sub(/-(#{PHASES.collect(&:to_s).join('|')})(\.csv)?$/, ''))
    @name = @file_name[@prefs[:blueprints_dir].length + 1..-1]
    PHASES.each do |phase|
      f = @file_name + '-' + phase.to_s + '.csv'
      if File.exists? f
        @multi_step = true
        @phases << phase
        @first_file ||= f
      end
    end
    @first_file.nil?
  end

  def exists?
    !@first_file.nil?
  end

  # @return [Blueprint]
  def load_from_csv(file)
    return self unless load_params_from_csv(file)
    @stack = PartialGridStack.new(@ml, @mx, @my) if @partial

    phases.each do |phase|
      if @multi_step
        fn = @file_name + '-' + phase.to_s + '.csv'
      else
        next if phase == :dig_alt
        fn = @file_name + '.csv'
      end
      if File.exists? fn
        y = 0
        l = @ol
        csv_munge_file(fn) do |row|
          if row[0] =~ /^#\s*([<>])?/
            if $1
              l = ($1 == '<' ? l + 1 : l - 1)
            end
            y = 0
          else
            cg = @stack.grid(l)
            row.each_with_index do |c, x|
              next if c.nil?
              c.strip!
              next if c.empty? || c == '~' || c == '´' || c == '`'
              break if c == '#'
              cg.provide(x + @ox, y + @oy, PHASES_TO_Z[phase]) do |v, sx, sy, sz|
                v.reverse_command(phase, c)
              end
            end
            y += 1
          end
        end
        @stack.refresh
      end
    end
    @stack.cx = @cx
    @stack.cy = @cy
    @stack.show_center = @show_center
    @stack.selected = 0
    @valid = true
  rescue Exception => e
    @valid = false
  ensure
    return self
  end

  def load_params_from_csv(file)
    init_from_filename(file)
    @valid = false
    return false unless @first_file
    @native = false
    @ox = 0
    @oy = 0
    @ol = 0

    @mx = 0
    @my = 0
    @ml = 1

    y = nil
    l = 0

    csv_munge_file(@first_file) do |row|
      c = row[0]
      if c =~ /^#\s*(.*)\s*$/
        if y.nil? && !@multi_step && c =~ /^#\s*([a-zA-Z]+)\s*/
          s = $1.downcase.to_sym
          @phases = [ s ] if s == :dig || s == :build
        end
        cmd = $1
        y = 0
        if cmd == '>'
          l += 1
          @ml += 1
        elsif cmd == '<'
          l -= 1
          @ml += 1
        else
          if cmd =~ /^[a-z]+\s*start\s*\(\s*(-?\d+)\s*;\s*(-?\d+)\s*[^)]*\)(.*)$/i
            @cx = $1.to_i - 1
            @cy = $2.to_i - 1
            @comment = $3
          end
          if cmd =~ /DwarfMockup\s*\(\s*([^)]*)\s*\)/
            @native = true
            pars = $1.split(';')
            @ox = pars[0].to_i || 0
            @oy = pars[1].to_i || 0
            @ol = pars[2].to_i || 0
            if pars[3]
              @show_center = pars[3].to_i == 1
            else
              @show_center = true
            end
            @cx += @ox
            @cy += @oy
            @comment.sub!(/ - DwarfMockup.*$/, '')
            @comment.sub!(/^ - /, '')
            break unless @partial
          end
        end
      else
        @mx = [ (row.count - (row[-1] == '#' ? 2 : 1 )), @mx ].max
        @my = [ y, @my ].max
        y += 1
      end
    end
    @valid = true
    if @partial
      @ox = 0
      @oy = 0
      @ol = 0
      @cx = 1
      @cy = 1
      @mx += 1
      @my += 1
    else
      if @ox == 0
        @ox = ((@stack.width - @mx) / 2).to_i
        @oy = ((@stack.height - @my) / 2).to_i
        @ol = ((@ml - 1) / 2).to_i
      end
      if @cx == 0
        @cx = @ox
        @cy = @oy
      end
    end

  rescue Exception => e
    @valid = false
  ensure
    return @valid
  end

  def csv_munge_file(fn)
    File.open(fn, :encoding => 'UTF-8') do |f|
      f.each_line do |l|
        row = []
        begin
          row = CSV.parse(l).first
        rescue CSV::MalformedCSVError => e
          row = [ l ]
        end
        yield row
      end
    end
  end

  def save_to_csv
    @native = true
    @valid = true
    @multi_step = true
    @phases = PHASES.dup
    @file_name = File.join(@prefs[:blueprints_dir], @name)

    rl, rx, ry = @stack.used_range
    rx = 0..0 if rx.begin > rx.end
    ry = 0..0 if ry.begin > ry.end
    rl = 0..0 if rl.begin > rl.end

    @phases.each do |phase|
      rz = PHASES_TO_Z[phase]
      fn = "#{@file_name}-#{phase}.csv"
      empty = true
      CSV.open(fn, 'wb') do |csv|
        csv << [ "##{PHASES_COMMANDS[phase]} start(#{(@stack.cx - rx.begin) + 1};#{(@stack.cy - ry.begin) + 1}; ) - #{@comment} - DwarfMockup(#{rx.begin};#{ry.begin};#{rl.end};#{@stack.show_center ? '1' : '0' })" ]
        r = []
        @stack.reverse_each do |g|
          next unless rl.include? g.level
          g.window_range(rx, ry, rz) do |v, x, y, z|
            t = (v ? v.command(phase) : '~')
            #t = (g[x, y, 0].wall? ? '~' : '~') if phase != :dig && t == '~'
            r << t
            empty = false unless t == '~'
            if x == rx.max
              r << '#'
              csv << r
              r = []
            end
          end
          csv << [ (g.level == rl.begin ? '#' : '#>' ) ] + [ '#' ] * ((rx.end - rx.begin) + 1)
        end
      end
      File.unlink(fn) if empty
    end
  end

  def valid?
    @valid
  end

  def complete?
    @complete
  end
end