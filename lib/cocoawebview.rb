# frozen_string_literal: true

require 'json'
require_relative "cocoawebview/version"
require_relative "cocoawebview/cocoawebview"

module CocoaWebview
  NSWindowStyleMaskResizable = 8
  NSWindowStyleMaskMiniaturizable = 4
  NSWindowStyleMaskTitled = 1
  NSWindowStyleMaskClosable = 2
  NSWindowStyleMaskFullSizeContentView = (1 << 15)
  NSWindowStyleMaskFullScreen = (1 << 14)

  class Error < StandardError; end
  # Your code goes here...
  
  class NSMenu
    def main_menu
      @menu
    end

    def main_menu_bar
      @menu_bar
    end
  end

  class NSApp
    def app_did_launch
      puts "NSApp did launch"
    end

    def dock_did_click
      puts "Dock icon clicked"
    end

    def app_will_exit
      puts "NSApp will exit"
    end
  end

  class CocoaWebview
    attr_accessor :callback

    def self.create(debug: false, min: true, resize: true, close: true, move_title_buttons: false, delta_y: 10, hide_title_bar: true, &block)
      style = NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView

      style = style | NSWindowStyleMaskMiniaturizable if min
      style = style | NSWindowStyleMaskResizable if resize
      style = style | NSWindowStyleMaskClosable if close

      if hide_title_bar
        style &= ~NSWindowStyleMaskFullScreen
      end

      webview = new(debug, style, move_title_buttons, delta_y, hide_title_bar)
      webview.callback = block
      webview
    end

    def get_webview
      @webview
    end

    def webview_did_load
      puts "CocoaWebview did loaded"
    end

    def file_did_drop(files)
      puts "Dropped below files:"
      puts "#{files}"
    end

    def bind(name, &block)
      param_info = block.parameters
      param_count = param_info.count { |type, _| type == :req || type == :opt }
      args = (1..param_count).map { |i| "arg#{i}" }.join(", ")
      code = %`
        function #{name}(#{args}) {
          body = {"function": "#{name}", args: [#{args}]};
          window.webkit.messageHandlers.native.postMessage(JSON.stringify(body));
        }
      `
      @bindings[name] = block
      self.eval(code)
    end

    def webview_msg_handler(msg)
      hash = JSON.parse(msg)
      function = hash["function"]
      args = hash["args"]
      callback = @bindings[function]
      callback.call(*args) if callback
    end
  end
end
