#import <AppKit/AppKit.h>
#include <stdbool.h>
#include <stdio.h>

static float gScreenWidth = 1280;
static float gScreenHeight = 720;
static const char *gWindowTitle = "Metal Playground";
static bool gRunning;

@interface MainWindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation MainWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
  gRunning = false;
}

@end

int main() {
  printf("Hello\n");

  NSRect screenRect = [NSScreen mainScreen].frame;
  NSRect initialFrame =
      NSMakeRect((screenRect.size.width - gScreenWidth) * 0.5f,
                 (screenRect.size.height - gScreenHeight) * 0.5f, gScreenWidth,
                 gScreenHeight);
  NSWindowStyleMask windowStyle =
      NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
      NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

  NSWindow *window =
      [[NSWindow alloc] initWithContentRect:initialFrame
                                  styleMask:windowStyle
                                    backing:NSBackingStoreBuffered
                                      defer:NO];
  [window setBackgroundColor:NSColor.redColor];
  [window setTitle:[NSString stringWithUTF8String:gWindowTitle]];
  [window makeKeyAndOrderFront:nil]; // Display the window

  MainWindowDelegate *mainWindowDelegate = [[MainWindowDelegate alloc] init];
  [window setDelegate:mainWindowDelegate];

  gRunning = true;

  while (gRunning) {
    NSEvent *event;

    do {
      event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                 untilDate:nil
                                    inMode:NSDefaultRunLoopMode
                                   dequeue:YES];

      switch (event.type) {
      default:
        [NSApp sendEvent:event];
      }

    } while (event != nil);
  }

  return 0;
}