#import <Cocoa/Cocoa.h>
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

}
- (id)initWithFrame:(NSRect)frame;
@end

@implementation CocoaWebview
- (id)initWithFrame:(NSRect)frame{
    self = [super initWithContentRect:frame
                            styleMask:(NSWindowStyleMaskTitled |
                                       NSWindowStyleMaskClosable |
                                       NSWindowStyleMaskResizable)
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        [self setTitle:@"My Custom Window"];
    }
    return self;
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
