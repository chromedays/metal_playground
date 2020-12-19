#include "renderer.h"
#include "gui.h"
#import <AppKit/AppKit.h>
#include <stdbool.h>
#include <stdio.h>

const char *gWindowTitleBase = "Metal Playground";
bool gRunning;
float gScreenWidth = 1280;
float gScreenHeight = 720;

@interface ViewDelegate : NSObject <MTKViewDelegate>
@end
@implementation ViewDelegate
- (void)drawInMTKView:(MTKView *)view {
  render(view, 1.f / view.preferredFramesPerSecond);
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
  gScreenWidth = size.width;
  gScreenHeight = size.height;
}
@end

@interface ViewController : NSViewController {
  MTKView *mtkView;
  ViewDelegate *mtkViewDelegate;
}
@end

@implementation ViewController

- (void)loadView {
  self.view = [[MTKView alloc]
      initWithFrame:NSMakeRect(0, 0, gScreenWidth, gScreenHeight)];
  mtkViewDelegate = [[ViewDelegate alloc] init];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  mtkView = (MTKView *)self.view;
  mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
  initRenderer(mtkView);
  mtkView.delegate = mtkViewDelegate;

  [mtkView setPreferredFramesPerSecond:60];

  NSTrackingArea *trackingArea = [[NSTrackingArea alloc]
      initWithRect:NSZeroRect
           options:NSTrackingMouseMoved | NSTrackingInVisibleRect |
                   NSTrackingActiveAlways
             owner:self
          userInfo:nil];
  [self.view addTrackingArea:trackingArea];
  NSEventMask eventMask = NSEventMaskKeyDown | NSEventMaskKeyUp |
                          NSEventMaskFlagsChanged | NSEventTypeScrollWheel;
  [NSEvent
      addLocalMonitorForEventsMatchingMask:eventMask
                                   handler:^NSEvent *_Nullable(NSEvent *event) {
                                     BOOL wantsCapture =
                                         guiHandleOSXEvent(event, mtkView);
                                     if (event.type == NSEventTypeKeyDown &&
                                         wantsCapture) {
                                       return nil;
                                     } else {
                                       return event;
                                     }
                                   }];
}

- (void)mouseMoved:(NSEvent *)event {
  guiHandleOSXEvent(event, mtkView);
}

- (void)mouseDown:(NSEvent *)event {
  guiHandleOSXEvent(event, mtkView);
}

- (void)mouseUp:(NSEvent *)event {
  guiHandleOSXEvent(event, mtkView);
}

- (void)mouseDragged:(NSEvent *)event {
  guiHandleOSXEvent(event, mtkView);
}

- (void)scrollWheel:(NSEvent *)event {
  guiHandleOSXEvent(event, mtkView);
}

- (void)setRepresentedObject:(id)representedObject {
  [super setRepresentedObject:representedObject];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate> {
  NSWindow *window;
}
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  NSRect screenRect = [NSScreen mainScreen].frame;
  NSRect initialFrame =
      NSMakeRect((screenRect.size.width - gScreenWidth) * 0.5f,
                 (screenRect.size.height - gScreenHeight) * 0.5f, gScreenWidth,
                 gScreenHeight);
  NSWindowStyleMask windowStyle =
      NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
      NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

  window = [[NSWindow alloc] initWithContentRect:initialFrame
                                       styleMask:windowStyle
                                         backing:NSBackingStoreBuffered
                                           defer:NO];
  [window setBackgroundColor:NSColor.redColor];
  [window setTitle:[NSString stringWithUTF8String:gWindowTitleBase]];
  [window setContentViewController:[[ViewController alloc] init]];
  [window makeKeyAndOrderFront:nil]; // Display the window
}
@end

int main(int argc, const char **argv) {
  printf("Hello\n");
  AppDelegate *appDelegate = [[AppDelegate alloc] init];
  [[NSApplication sharedApplication] setDelegate:appDelegate];
  return NSApplicationMain(argc, argv);
  // gRunning = true;

  // while (gRunning) {
  //   NSEvent *event;

  //   do {
  //     event = [NSApp nextEventMatchingMask:NSEventMaskAny
  //                                untilDate:nil
  //                                   inMode:NSDefaultRunLoopMode
  //                                  dequeue:YES];

  //     switch (event.type) {
  //     default:
  //       [NSApp sendEvent:event];
  //     }

  //   } while (event != nil);

  //   [metalView draw];
  // }
}