# frozen_string_literal: true

require 'json'
require_relative "cocoawebview/version"
require_relative "cocoawebview/cocoawebview"

module CocoaWebview
  class Error < StandardError; end
  # Your code goes here...

  class NSApp
    def app_did_launch
      puts "NSApp did launch"
    end
  end

  class CocoaWebview
    def get_webview
      @webview
    end

    def webview_did_load
      puts "CocoaWebview did loaded"
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
