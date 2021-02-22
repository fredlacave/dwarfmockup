#! /usr/local/bin/ruby
# encoding: utf-8

ocra = ENV['OCRA_EXECUTABLE'] rescue nil

require 'fileutils'

if Gem.win_platform?
  if ocra && !ocra.empty?
    EXEC_PATH = File.dirname(File.expand_path(__FILE__)).gsub(/\//, '\\')
    # IMAGE_MAGICK_PATH = EXEC_PATH + '\\vendor\\ImageMagick-6.6.9-Q8'
    # ENV['PATH'] = IMAGE_MAGICK_PATH + ';' + ENV['PATH']
    ENV['BUNDLE_GEMFILE'] = EXEC_PATH + '\\Gemfile'
    APP_PATH = File.dirname(File.expand_path(ocra))
    rd = File.join(APP_PATH, 'res')
    FileUtils.cp_r(File.join(EXEC_PATH, 'res'), rd) unless File.exists?(rd)
  else
    require 'win32/api'
    APP_PATH = File.dirname(File.expand_path(__FILE__))
    EXEC_PATH = APP_PATH
  end
else
  APP_PATH = File.dirname(File.expand_path(__FILE__))
  EXEC_PATH = APP_PATH
end

require 'bundler'
Bundler.require

require 'csv'
require 'singleton'
require 'thread'

require_relative 'lib/misc/const'
require_relative 'lib/misc/extend'
require_relative 'lib/misc/resource'
require_relative 'lib/misc/preferences'

require_relative 'lib/ui/gamewindow'
require_relative 'lib/ui/inputbox'
require_relative 'lib/ui/fileinputbox'
require_relative 'lib/ui/messagebox'
require_relative 'lib/ui/waitdialog'
require_relative 'lib/ui/textscrollbox'
require_relative 'lib/ui/dialogchains'

require_relative 'lib/grids/blueprint'
require_relative 'lib/grids/gridstack'
require_relative 'lib/grids/grid'
require_relative 'lib/grids/tile'
require_relative 'lib/grids/selection'

Thread.abort_on_exception = true

#p = RubyProf.profile do
$main = GameWindow.new(Preferences.instance.load(APP_PATH))
$main.setup
$main.show unless defined? Ocra
#end
#File.open('./profile', 'w') do |h|
#  RubyProf::FlatPrinter.new(p).print(h)
#  RubyProf::FlatPrinterWithLineNumbers.new(p).print(h)
#  RubyProf::GraphPrinter.new(p).print(h)
#end
