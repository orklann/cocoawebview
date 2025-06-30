#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include "cocoawebview.h"

VALUE rb_mCocoawebview;
VALUE rb_mNSAppClass = Qnil;
VALUE rb_mCocoaWebviewClass = Qnil;
NSApplication *application = nil;

VALUE nsapp_initialize(VALUE self);
VALUE nsapp_run(VALUE self);

VALUE webview_initialize(VALUE self, VALUE debug);
VALUE webview_show(VALUE self);
VALUE webview_hide(VALUE self);
VALUE webview_eval(VALUE self, VALUE code);
VALUE webview_set_size(VALUE self, VALUE width, VALUE height);
VALUE webview_get_size(VALUE self);
VALUE webview_set_pos(VALUE self, VALUE x, VALUE y);
VALUE webview_get_pos(VALUE self);
VALUE webview_dragging(VALUE self);

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    VALUE app;
}
@end

@implementation AppDelegate

- (void)setApp:(VALUE)a {
    app = a;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    rb_funcall(app, rb_intern("app_did_launch"), 0);
}
@end

@interface CocoaWebview : NSWindow <WKScriptMessageHandler> {
    WKWebView *webView;
    VALUE rb_cocoawebview;
    BOOL showDevTool;
}
- (void)setDevTool:(BOOL)flag;
- (id)initWithFrame:(NSRect)frame debug:(BOOL)flag;
- (void)eval:(NSString*)code;
- (void)setCocoaWebview:(VALUE)view;
- (void)dragging;
@end

@implementation CocoaWebview
- (id)initWithFrame:(NSRect)frame debug:(BOOL)flag {
    int style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                 NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskFullSizeContentView;
    style &= ~NSWindowStyleMaskFullScreen;
    self = [super initWithContentRect:frame
                            styleMask:style
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        [self center];
        [self setTitle:@"My Custom Window"];
        [self setDevTool:flag];
        [self setTitlebarAppearsTransparent: YES];
        [self addWebViewToWindow:self];
    }
    return self;
}

- (void)close {
    [self orderOut:nil]; // Hide instead of destroy
}

- (void)windowWillClose:(NSNotification *)notification {
    // Prevent release by hiding the window instead
    [notification.object orderOut:nil];
}

- (void)dragging {
    NSEvent *event = [NSApp currentEvent];
    [self performWindowDragWithEvent:event];
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"native"]) {
        const char *body = [message.body UTF8String];
        VALUE rb_body = rb_str_new_cstr(body);
        rb_funcall(rb_cocoawebview, rb_intern("webview_msg_handler"), 1, rb_body);
    }
}

- (void)setDevTool:(BOOL)flag {
    showDevTool = flag;
}

- (void)setCocoaWebview:(VALUE)view {
    rb_cocoawebview = view;
}

- (void)eval:(NSString*)code {
    [webView evaluateJavaScript:code completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"JavaScript error: %@", error);
        }
    }];
}

- (void)addWebViewToWindow:(NSWindow *)window {
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    [userContentController addScriptMessageHandler:self name:@"native"];

    // Create a configuration if needed
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];

    [[config preferences] setValue:@YES forKey:@"fullScreenEnabled"];

    config.userContentController = userContentController;
    if (showDevTool) {
        [[config preferences] setValue:@YES forKey:@"developerExtrasEnabled"];
    }

    [[config preferences] setValue:@YES forKey:@"javaScriptCanAccessClipboard"];

    [[config preferences] setValue:@YES forKey:@"DOMPasteAllowed"];

    // Create the WKWebView with the configuration
    NSRect contentRect = [[window contentView] bounds];
    webView = [[WKWebView alloc] initWithFrame:contentRect configuration:config];

    // Enable autoresizing
    [webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    // Load a URL
    /*
    NSURL *url = [NSURL URLWithString:@"https://www.apple.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [webView loadRequest:request];
    */

    // Add to window's contentView
    [window setContentView:webView];

    webView.navigationDelegate = self;
}

// Called when the web view finishes loading
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    rb_funcall(rb_cocoawebview, rb_intern("webview_did_load"), 0);
}
@end

static void cocoawebview_obj_free(void *ptr) {

}

static const rb_data_type_t cocoawebview_obj_type = {
    "CocoaWebviewWrapper",
    { 0, cocoawebview_obj_free, 0 },
    0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};


RUBY_FUNC_EXPORTED void
Init_cocoawebview(void)
{
  rb_mCocoawebview = rb_define_module("CocoaWebview");

  /* NSApp */
  rb_mNSAppClass = rb_define_class_under(rb_mCocoawebview, "NSApp", rb_cObject);
  rb_define_method(rb_mNSAppClass, "initialize", nsapp_initialize, 0);
  rb_define_method(rb_mNSAppClass, "run", nsapp_run, 0);

  /* CocoaWebview */
  rb_mCocoaWebviewClass = rb_define_class_under(rb_mCocoawebview, "CocoaWebview", rb_cObject);
  rb_define_method(rb_mCocoaWebviewClass, "initialize", webview_initialize, 1);
  rb_define_method(rb_mCocoaWebviewClass, "show", webview_show, 0);
  rb_define_method(rb_mCocoaWebviewClass, "hide", webview_hide, 0);
  rb_define_method(rb_mCocoaWebviewClass, "eval", webview_eval, 1);
  rb_define_method(rb_mCocoaWebviewClass, "set_size", webview_set_size, 2);
  rb_define_method(rb_mCocoaWebviewClass, "get_size", webview_get_size, 0);
  rb_define_method(rb_mCocoaWebviewClass, "set_pos", webview_set_pos, 2);
  rb_define_method(rb_mCocoaWebviewClass, "get_pos", webview_get_pos, 0);
  rb_define_method(rb_mCocoaWebviewClass, "dragging", webview_dragging, 0);
}

VALUE nsapp_initialize(VALUE self) {
  rb_iv_set(self, "@var", rb_hash_new());
  application = [NSApplication sharedApplication];
  AppDelegate *delegate = [[AppDelegate alloc] init];
  [delegate setApp:self];
  [application setDelegate:delegate];
  return self;
}

VALUE nsapp_run(VALUE self) {
    [application run];
}

VALUE webview_initialize(VALUE self, VALUE debug) {
  rb_iv_set(self, "@var", rb_hash_new());
  rb_iv_set(self, "@bindings", rb_hash_new());
  BOOL flag = NO;
  if (debug == Qtrue) {
    flag = YES;
  } else {
    flag = NO;
  }
  CocoaWebview *webview = [[CocoaWebview alloc] initWithFrame:NSMakeRect(100, 100, 400, 500) debug:flag];

  [webview setReleasedWhenClosed:NO];
  [webview setCocoaWebview:self];

  // Wrap the Objective-C pointer into a Ruby object
  VALUE wrapper = TypedData_Wrap_Struct(rb_cObject, &cocoawebview_obj_type, webview);

  // Store the wrapper in an instance variable
  rb_ivar_set(self, rb_intern("@webview"), wrapper);
  return self;
}

VALUE webview_show(VALUE self) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);
    [webview makeKeyAndOrderFront:nil];
}

VALUE webview_hide(VALUE self) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);
    [webview orderOut:nil];
}

VALUE webview_eval(VALUE self, VALUE code) {
    const char *js = StringValueCStr(code);
    NSString *js_code = [[NSString alloc] initWithCString:js encoding:NSUTF8StringEncoding];

    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    [webview eval:js_code];
}

VALUE webview_set_size(VALUE self, VALUE width, VALUE height) {
    int c_width = NUM2INT(width);
    int c_height = NUM2INT(height);

    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    NSRect frame = [webview frame];
    frame.size = NSMakeSize(c_width, c_height);
    [webview setFrame:frame display:YES];
}

VALUE webview_get_size(VALUE self) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    NSRect frame = [webview frame];
    int width = (int)frame.size.width;
    int height = (int)frame.size.height;

    VALUE rb_width = INT2NUM(width);
    VALUE rb_height = INT2NUM(height);

    VALUE ary = rb_ary_new();
    rb_ary_push(ary, rb_width);
    rb_ary_push(ary, rb_height);
    return ary;
}

VALUE webview_set_pos(VALUE self, VALUE x, VALUE y) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    int c_x = NUM2INT(x);
    int c_y = NUM2INT(y);

    NSPoint newOrigin = NSMakePoint(c_x, c_y);
    [webview setFrameOrigin:newOrigin];
}

VALUE webview_get_pos(VALUE self) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    NSRect frame = [webview frame];
    int x = frame.origin.x;
    int y = frame.origin.y;
    VALUE rb_x = INT2NUM(x);
    VALUE rb_y = INT2NUM(y);

    VALUE ary = rb_ary_new();
    rb_ary_push(ary, rb_x);
    rb_ary_push(ary, rb_y);
    return ary;
}

VALUE webview_dragging(VALUE self) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    [webview dragging];
}
