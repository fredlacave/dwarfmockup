#require "win32/api"

if Gem.win_platform?
  # Keep Ruymine quiet, since the rdoc of the call mehtod specifies 2 arguments
  module Win32
    class API
      alias_method :kall, :call
      def call(*args)
        self.__send__(:kall, *args)
      end
    end
  end
end

def hwnd
  if @hwnd.nil?
    enum_windows = Win32::API.new('EnumWindows', 'KP', 'L', 'user32')
    get_window_thread_process_id = Win32::API.new('GetWindowThreadProcessId', 'LP', 'L', 'user32')
    enum_windows_proc = Win32::API::Callback.new('LL', 'I') do |h, param|
      bfpid = 0.chr * 8
      get_window_thread_process_id.call(h, bfpid)
      if bfpid.unpack('L').first == param
        @hwnd = h
        0
      else
        1
      end
    end
    enum_windows.call(enum_windows_proc, Process.pid)
  end
  @hwnd
end

def update_window_size
  if Gem.win_platform? && !@prefs[:fullscreen]
    rww, rwh, oww, owh = get_window_size
    rect_p = [ 0, 0, oww, owh ].pack('l4')
    Win32::API.new('AdjustWindowRect', 'PLI', 'I', 'user32').call(rect_p, 0x06ca0000, 0)
    Win32::API.new('MoveWindow', 'LIIIII', 'I', 'user32').call(hwnd, 0, 0, oww, owh, 0)
    t = Win32::API.new('MoveWindow', 'LIIIII', 'I', 'user32').call(hwnd, 0, 0, oww, owh, 0)
    GL.Viewport(0, 0, rww, rwh)
    GL.Ortho(0, rww, rwh, 0, -1, 1)
  end
end

def get_window_size
  if Gem.win_platform? && !@prefs[:fullscreen]
    dy = Win32::API.new('GetSystemMetrics', 'L', 'L', 'user32').call(31)
    ws = Win32::API.new('GetSystemMetrics', 'L', 'L', 'user32').call(33)
    oww = @prefs[:window_width]
    owh = @prefs[:window_height]
    rww = @prefs[:window_width] - ws * 2
    rwh = @prefs[:window_height] - ws - dy
  else
    oww = rww = @prefs[:window_width]
    owh = rwh = @prefs[:window_height]
  end
  [ rww, rwh, oww, owh ]
end
