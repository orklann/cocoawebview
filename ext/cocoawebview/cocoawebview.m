#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include "cocoawebview.h"

VALUE rb_mCocoawebview;
VALUE rb_mNSAppClass = Qnil;
VALUE rb_mCocoaWebviewClass = Qnil;
NSApplication *application = nil;

VALUE nsapp_initialize(VALUE self);
VALUE nsapp_run(VALUE self);
VALUE nsapp_exit(VALUE self);

VALUE webview_initialize(VALUE self, VALUE debug, VALUE style, VALUE move_title_buttons);
VALUE webview_show(VALUE self);
VALUE webview_hide(VALUE self);
VALUE webview_eval(VALUE self, VALUE code);
VALUE webview_set_size(VALUE self, VALUE width, VALUE height);
VALUE webview_get_size(VALUE self);
VALUE webview_set_pos(VALUE self, VALUE x, VALUE y);
VALUE webview_get_pos(VALUE self);
VALUE webview_dragging(VALUE self);
VALUE webview_set_title(VALUE self, VALUE title);
VALUE webview_center(VALUE self);
VALUE webview_is_visible(VALUE self);
VALUE webview_set_topmost(VALUE self, VALUE topmost);
VALUE webview_set_bg(VALUE self, VALUE r, VALUE g, VALUE b, VALUE a);

@interface FileDropContainerView : NSView {
    VALUE rb_cocoawebview;
}

- (void)setObj:(VALUE)o;
@end

@implementation FileDropContainerView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
    return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    NSArray<NSURL *> *fileURLs = [pasteboard readObjectsForClasses:@[[NSURL class]]
                                                           options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];

    VALUE files = rb_ary_new();
    for (int i = 0; i < fileURLs.count; i++) {
        NSString *filePath = fileURLs[i].path;
        VALUE ruby_file_path = rb_str_new_cstr([filePath UTF8String]);
        rb_ary_push(files, ruby_file_path);
    }

    if (fileURLs.count > 0) {
        rb_funcall(rb_cocoawebview, rb_intern("file_did_drop"), 1, files);
        return YES;
    }
    return NO;
}

- (void)setObj:(VALUE)o {
    rb_cocoawebview = o;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor clearColor] setFill];
    NSRectFill(dirtyRect);
}
@end

@interface CocoaWKWebView : WKWebView
@property (nonatomic, strong) NSEvent *lastMouseDownEvent;
@end

@implementation CocoaWKWebView

- (void)mouseDown:(NSEvent *)event {
    self.lastMouseDownEvent = event;
    [super mouseDown:event];
}
@end


@interface AppDelegate : NSObject <NSApplicationDelegate> {
    VALUE app;
}
@end

@implementation AppDelegate

- (void)setApp:(VALUE)a {
    app = a;
}

- (void)appBecameActive:(NSNotification *)notification {
    rb_funcall(app, rb_intern("dock_did_click"), 0);
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
   [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appBecameActive:)
                                                 name:NSApplicationDidBecomeActiveNotification
                                               object:nil];
    rb_funcall(app, rb_intern("app_did_launch"), 0);
}
@end

@interface CocoaWebview : NSWindow <WKScriptMessageHandler> {
    CocoaWKWebView *webView;
    VALUE rb_cocoawebview;
    BOOL showDevTool;
    BOOL shouldMoveTitleButtons;
    FileDropContainerView *fileDropView;
}
- (void)setShouldMoveTitleButtons:(BOOL)flag;
- (void)setDevTool:(BOOL)flag;
- (id)initWithFrame:(NSRect)frame debug:(BOOL)flag style:(int)style moveTitleButtons:(BOOL)moveTitleButtons;
- (void)eval:(NSString*)code;
- (void)setCocoaWebview:(VALUE)view;
- (void)dragging;
@end

@implementation CocoaWebview
- (id)initWithFrame:(NSRect)frame debug:(BOOL)flag style:(int)style moveTitleButtons:(BOOL)moveTitleButtons{
    self = [super initWithContentRect:frame
                            styleMask:style
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        [self center];
        [self setTitle:@"My Custom Window"];
        [self setDevTool:flag];
        [self setTitlebarAppearsTransparent: YES];
        [self setTitleVisibility:NSWindowTitleHidden];
        [self addWebViewToWindow:self];
        [self setShouldMoveTitleButtons:moveTitleButtons];
        if (moveTitleButtons) {
            [self moveWindowButtonsForWindow:self];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowDidResize:)
                                                     name:NSWindowDidResizeNotification
                                                   object:self];
    }
    return self;
}

- (void)setShouldMoveTitleButtons:(BOOL)flag {
    shouldMoveTitleButtons = flag;
}

- (void)windowDidResize:(NSNotification *)notification {
    if (shouldMoveTitleButtons) {
        [self moveWindowButtonsForWindow:self];
    }
}

- (void)moveWindowButtonsForWindow:(NSWindow *)window {
    //Close Button
    NSButton *closeButton = [window standardWindowButton:NSWindowCloseButton];
    [closeButton setFrameOrigin:NSMakePoint(closeButton.frame.origin.x + 10, closeButton.frame.origin.y - 10)];

    //Minimize Button
    NSButton *minimizeButton = [window standardWindowButton:NSWindowMiniaturizeButton];
    [minimizeButton setFrameOrigin:NSMakePoint(minimizeButton.frame.origin.x + 10, minimizeButton.frame.origin.y - 10)];

    //Zoom Button
    NSButton *zoomButton = [window standardWindowButton:NSWindowZoomButton];
    [zoomButton setFrameOrigin:NSMakePoint(zoomButton.frame.origin.x + 10, zoomButton.frame.origin.y - 10)];
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
    [fileDropView setObj:view];
}

- (void)eval:(NSString*)code {
    [webView evaluateJavaScript:code completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"JavaScript error: %@", error);
        }
    }];
}

- (void)addWebViewToWindow:(NSWindow *)window {
    NSRect contentRect = [[window contentView] bounds];

    fileDropView = [[FileDropContainerView alloc] initWithFrame:contentRect];
    fileDropView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

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
    webView = [[CocoaWKWebView alloc] initWithFrame:contentRect configuration:config];

    // Enable autoresizing
    [webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    // Load a URL
    /*
    NSURL *url = [NSURL URLWithString:@"https://www.apple.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [webView loadRequest:request];
    */

    // Add to window's contentView
    [[window contentView] addSubview: webView];
    [[window contentView] addSubview:fileDropView positioned:NSWindowAbove relativeTo:webView];

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
  rb_define_method(rb_mNSAppClass, "exit", nsapp_exit, 0);

  /* CocoaWebview */
  rb_mCocoaWebviewClass = rb_define_class_under(rb_mCocoawebview, "CocoaWebview", rb_cObject);
  rb_define_method(rb_mCocoaWebviewClass, "initialize", webview_initialize, 3);
  rb_define_method(rb_mCocoaWebviewClass, "show", webview_show, 0);
  rb_define_method(rb_mCocoaWebviewClass, "hide", webview_hide, 0);
  rb_define_method(rb_mCocoaWebviewClass, "eval", webview_eval, 1);
  rb_define_method(rb_mCocoaWebviewClass, "set_size", webview_set_size, 2);
  rb_define_method(rb_mCocoaWebviewClass, "get_size", webview_get_size, 0);
  rb_define_method(rb_mCocoaWebviewClass, "set_pos", webview_set_pos, 2);
  rb_define_method(rb_mCocoaWebviewClass, "get_pos", webview_get_pos, 0);
  rb_define_method(rb_mCocoaWebviewClass, "dragging", webview_dragging, 0);
  rb_define_method(rb_mCocoaWebviewClass, "set_title", webview_set_title, 1);
  rb_define_method(rb_mCocoaWebviewClass, "center", webview_center, 0);
  rb_define_method(rb_mCocoaWebviewClass, "visible?", webview_is_visible, 0);
  rb_define_method(rb_mCocoaWebviewClass, "set_topmost", webview_set_topmost, 1);
  rb_define_method(rb_mCocoaWebviewClass, "set_bg", webview_set_bg, 4);

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

VALUE nsapp_exit(VALUE self) {
    [[NSApplication sharedApplication] terminate:nil];
}

VALUE webview_initialize(VALUE self, VALUE debug, VALUE style, VALUE move_title_buttons) {
  rb_iv_set(self, "@var", rb_hash_new());
  rb_iv_set(self, "@bindings", rb_hash_new());
  BOOL flag = NO;
  if (debug == Qtrue) {
    flag = YES;
  } else {
    flag = NO;
  }

  BOOL c_move_title_buttons = NO;
  if (move_title_buttons == Qtrue) {
    c_move_title_buttons = YES;
  } else {
    c_move_title_buttons = NO;
  }
  int c_style = NUM2INT(style);
  CocoaWebview *webview = [[CocoaWebview alloc] initWithFrame:NSMakeRect(100, 100, 400, 500) debug:flag style:c_style moveTitleButtons:c_move_title_buttons];

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
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
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

VALUE webview_set_title(VALUE self, VALUE title) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    const char *c_title = StringValueCStr(title);
    NSString *title_str = [[NSString alloc] initWithCString:c_title encoding:NSUTF8StringEncoding];
    [webview setTitle:title_str];
}

VALUE webview_center(VALUE self) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    [webview center];
}

VALUE webview_is_visible(VALUE self) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    if ([webview isVisible]) {
        return Qtrue;
    } else {
        return Qfalse;
    }
}

VALUE webview_set_topmost(VALUE self, VALUE topmost) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    bool c_topmost = RTEST(topmost);

    if (c_topmost) {
        [webview setLevel:NSFloatingWindowLevel];
    } else {
        [webview setLevel:NSNormalWindowLevel];
    }
}

VALUE webview_set_bg(VALUE self, VALUE r, VALUE g, VALUE b, VALUE a) {
    VALUE wrapper = rb_ivar_get(self, rb_intern("@webview"));
    CocoaWebview *webview;
    TypedData_Get_Struct(wrapper, CocoaWebview, &cocoawebview_obj_type, webview);

    double c_r = NUM2DBL(r);
    double c_g = NUM2DBL(g);
    double c_b = NUM2DBL(b);
    double c_a = NUM2DBL(a);

    NSColor *rgbColor = [NSColor colorWithSRGBRed:c_r
                                        green:c_g
                                         blue:c_b
                                        alpha:c_a];
    [webview setBackgroundColor:rgbColor];
}
