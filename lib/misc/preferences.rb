#! /usr/local/bin/ruby
# encoding: utf-8

require 'gosu'
require 'singleton'
require 'fileutils'

class Preferences
  class << self
    # @!method instance
    #   @return [Preferences]
  end
  include Singleton
  attr_accessor :prefs, :dir, :file, :dir_exe


  def load(dir)
    @prefs = Hash.new { |h, k| h[k] = '' }
    @dir = File.expand_path(dir)
    @dir_exe = File.expand_path(File.join(File.dirname(__FILE__), ".." , ".."))
    @file = File.join(@dir, 'dwarfmockup.conf')
    FileUtils.cp(File.join(@dir_exe, 'res/defaults/dwarfmockup.conf'), @file) unless File.exists? @file
    context = @prefs
    File.open(@file) do |h|
      h.each_line do |l|
        l.chomp!
        l.gsub!(/#.*$/, '')
        l.strip!
        next if l.empty?
        if l =~ /^\[([a-zA-Z0-9]+)\]$/
          @prefs[$1.to_sym] = {}
          context = @prefs[$1.to_sym]
        elsif l =~ /^(.*)=(.*)$/
          context[$1.strip.to_sym] = $2.strip
        else
          context[l.to_sym] = true
        end
      end
    end

    load_defaults
    Dir.mkdir(@prefs[:blueprints_dir]) unless File.exists? @prefs[:blueprints_dir]
    self
  end

  def load_defaults
    @prefs[:blueprints_dir] = File.join(dir, "blueprints") if @prefs[:blueprints_dir].empty?
    @prefs[:window_width] = 1024                           if @prefs[:window_width].empty?
    @prefs[:window_height] = 768                           if @prefs[:window_height].empty?
    @prefs[:fullscreen] = "false"                          if @prefs[:fullscreen].empty?
    @prefs[:ghost] = "false"                               if @prefs[:ghost].empty?
    @prefs[:crosshairs] = "false"                          if @prefs[:crosshairs].empty?
    @prefs[:font_name] = "VeraMono"                        if @prefs[:font_name].empty?
    @prefs[:fonts_dir] = @dir_exe + "/res/fonts"           if @prefs[:fonts_dir].empty?
    @prefs[:tiles_name] = "mayday"                         if @prefs[:tiles_name].empty?
    @prefs[:tiles_dir] = @dir_exe + "/res/tiles"           if @prefs[:tiles_dir].empty?
    @prefs[:tile_size] = 16                                if @prefs[:tile_size].empty?
    @prefs.each { |k, v| @prefs[k] = File.expand_path(v) if k =~ /_dir$/ }

    [:window_width, :window_height, :tile_size ].each do |k|
      @prefs[k] = @prefs[k].to_i
    end

    [ :fullscreen, :ghost, :crosshairs ].each do |k|
      @prefs[k] = !(%w(false 0 f n no).include?(@prefs[k]))
    end

    @prefs[:tiles].each do |k, v|
      if v =~ /,/
        @prefs[:tiles][k] = v.split(',').collect { |e| e.to_i }
      else
        @prefs[:tiles][k] = v.to_i
      end
    end
  end

  def [](v)
    @prefs[v]
  end
end