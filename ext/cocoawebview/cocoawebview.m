#import <Cocoa/Cocoa.h>
#include "cocoawebview.h"

VALUE rb_mCocoawebview;
VALUE rb_mNSAppClass = Qnil;
NSApplication *application = nil;

VALUE nsapp_initialize(VALUE self);
VALUE nsapp_run(VALUE self);

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


RUBY_FUNC_EXPORTED void
Init_cocoawebview(void)
{
  rb_mCocoawebview = rb_define_module("CocoaWebview");
  rb_mNSAppClass = rb_define_class_under(rb_mCocoawebview, "NSApp", rb_cObject);
  rb_define_method(rb_mNSAppClass, "initialize", nsapp_initialize, 0);
  rb_define_method(rb_mNSAppClass, "run", nsapp_run, 0);
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
