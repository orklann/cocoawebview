# frozen_string_literal: true

require "mkmf"

# Makes all symbols private by default to avoid unintended conflict
# with other gems. To explicitly export symbols you can use RUBY_FUNC_EXPORTED
# selectively, or entirely remove this flag.
append_cflags("-fvisibility=hidden")

have_framework("Cocoa")

$CFLAGS << " -ObjC"

# Add Cocoa framework to linker flags
$LDFLAGS << " -framework Cocoa"

# Add Webview framework to linker flags
$LDFLAGS << " -framework WebKit"

create_makefile("cocoawebview/cocoawebview")
