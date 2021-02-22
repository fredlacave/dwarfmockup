#! /usr/local/bin/ruby
# encoding: utf-8

require_relative "dialog"
require_relative "inputbox"

class FileInputBox < InputBox
  def initialize(window, title, default, dir, ext, filter = nil, &block)
    super(window, title, default, &block)
    @dir = dir
    @ext = ext.sub(/^\.*/, '')
    @list_pos = -1
    @file_list = nil
    @filter = filter
  end

  def key_press(key)
    if key == Gosu::KbTab
      op = self.caret_pos
      if @list_pos == -1
        r = @dir + "/" + self.text[0..op]
        @file_list = (Dir.glob(r + "*." + @ext, File::FNM_NOESCAPE).collect { |e| e[(@dir.length + 1)..-(@ext.empty? ? 1 : @ext.length + 2)] } +
                      Dir.glob(r, File::FNM_NOESCAPE).collect { |e| e[(@dir.length + 1)..-1] + '/' if File.directory?(e) }).compact.sort
        if @filter
          @file_list = @file_list.collect { |e| e.sub(@filter, '').gsub(/\/\/+/, '/').gsub(/\\\\+/, '\\') }.uniq.sort
        end
        unless @file_list.empty?
          @list_pos = 0
          self.text = @file_list[0]
        end
      else
        @list_pos = (@list_pos + 1) % @file_list.length
        self.text = @file_list[@list_pos]
      end
      self.caret_pos = op
    else
      unless key == 67
        @list_pos = -1
      end
      super
    end
  end
end
