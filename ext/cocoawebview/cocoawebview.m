#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include "cocoawebview.h"

VALUE rb_mCocoawebview;
VALUE rb_mNSAppClass = Qnil;
VALUE rb_mCocoaWebviewClass = Qnil;
NSApplication *application = nil;

VALUE nsapp_initialize(VALUE self);
VALUE nsapp_run(VALUE self);

VALUE webview_initialize(VALUE self);
VALUE webview_show(VALUE self);
VALUE webview_hide(VALUE self);
VALUE webview_eval(VALUE self, VALUE code);


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

@interface CocoaWebview : NSWindow {
    WKWebView *webView;
    VALUE rb_cocoawebview;
}
- (id)initWithFrame:(NSRect)frame;
- (void)eval:(NSString*)code;
- (void)setCocoaWebview:(VALUE)view;
@end

@implementation CocoaWebview
- (id)initWithFrame:(NSRect)frame{
    int style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                 NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskFullSizeContentView;
    style &= ~NSWindowStyleMaskFullScreen;
    self = [super initWithContentRect:frame
                            styleMask:style
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        [self setTitle:@"My Custom Window"];
        [self setTitlebarAppearsTransparent: YES];
        [self addWebViewToWindow:self];
    }
    return self;
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
    // Create a configuration if needed
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];

    [[config preferences] setValue:@YES forKey:@"fullScreenEnabled"];

    [[config preferences] setValue:@YES forKey:@"developerExtrasEnabled"];

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

    NSString *html = @"<html><body><h1>Hello from WKWebView</h1><script>function sayHello() { console.log('Hello JS!'); }</script></body></html>";
    [webView loadHTMLString:html baseURL:nil];
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
  rb_define_method(rb_mCocoaWebviewClass, "initialize", webview_initialize, 0);
  rb_define_method(rb_mCocoaWebviewClass, "show", webview_show, 0);
  rb_define_method(rb_mCocoaWebviewClass, "hide", webview_hide, 0);
  rb_define_method(rb_mCocoaWebviewClass, "eval", webview_eval, 1);
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

VALUE webview_initialize(VALUE self) {
  rb_iv_set(self, "@var", rb_hash_new());
  CocoaWebview *webview = [[CocoaWebview alloc] initWithFrame:NSMakeRect(100, 100, 400, 500)];

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
