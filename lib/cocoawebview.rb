# frozen_string_literal: true

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
  end
end
