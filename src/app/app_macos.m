#include "../app.h"
#include "../util.h"
#include "../renderer.h"
#include "../gui.h"
#import <AppKit/AppKit.h>
#include <stdbool.h>
#include <stdio.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

static App gApp;
App *getApp(void) { return &gApp; }

@interface ViewDelegate : NSObject <MTKViewDelegate> {
  uint64_t lastTimeCounter;
  mach_timebase_info_data_t timeBase;
}
@end
@implementation ViewDelegate

- (instancetype)init {
  self = [super init];
  lastTimeCounter = mach_absolute_time();
  mach_timebase_info(&timeBase);
  return self;
}

- (void)drawInMTKView:(MTKView *)view {
  uint64_t currTimeCounter = mach_absolute_time();
  uint64_t elapsedCounter = currTimeCounter - lastTimeCounter;
  uint64_t elapsedMS =
      elapsedCounter * timeBase.numer / (1000000 * timeBase.denom);
  lastTimeCounter = currTimeCounter;
  // LOG("%llu", elapsedMS);
  render(view, elapsedMS / 1000.f);
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
  gApp.width = size.width;
  gApp.height = size.height;
  onResizeWindow();
}
@end

@interface ViewController : NSViewController {
  MTKView *mtkView;
  ViewDelegate *mtkViewDelegate;
}
@end

@implementation ViewController

- (void)loadView {
  self.view =
      [[MTKView alloc] initWithFrame:NSMakeRect(0, 0, gApp.width, gApp.height)];
  mtkViewDelegate = [[ViewDelegate alloc] init];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  mtkView = (MTKView *)self.view;
  mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
  mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
  initRenderer(mtkView);
  mtkView.delegate = mtkViewDelegate;

  CGDisplayModeRef displayMode = CGDisplayCopyDisplayMode(CGMainDisplayID());
  double refreshRate = CGDisplayModeGetRefreshRate(displayMode);
  if ((int)refreshRate % 2 == 1) {
    refreshRate += 1;
  }
  CGDisplayModeRelease(displayMode);
  [mtkView setPreferredFramesPerSecond:refreshRate];

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

  // NSPoint mousePos = [mtkView convertPoint:event.locationInWindow
  // fromView:nil]; mousePos = NSMakePoint(mousePos.x,
  // mtkView.bounds.size.height - mousePos.y); onMouseDragged(mousePos.x,
  // mousePos.y);

  onMouseDragged([event deltaX], -[event deltaY]);
}

- (void)scrollWheel:(NSEvent *)event {
  guiHandleOSXEvent(event, mtkView);

  double dy = [event scrollingDeltaY] * 0.1;
  if ([event hasPreciseScrollingDeltas]) {
    dy *= 0.1;
  }

  onMouseScrolled((float)dy);
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
  NSRect initialFrame = NSMakeRect(
      (screenRect.size.width - gApp.width) * 0.5f,
      (screenRect.size.height - gApp.height) * 0.5f, gApp.width, gApp.height);
  NSWindowStyleMask windowStyle =
      NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
      NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

  window = [[NSWindow alloc] initWithContentRect:initialFrame
                                       styleMask:windowStyle
                                         backing:NSBackingStoreBuffered
                                           defer:NO];
  [window setBackgroundColor:NSColor.redColor];
  [window setTitle:[NSString stringWithUTF8String:gApp.title.buf]];
  [window setContentViewController:[[ViewController alloc] init]];
  [window makeKeyAndOrderFront:nil]; // Display the window
}
@end

int runMain(UNUSED int argc, UNUSED char **argv, const char *title, int width,
            int height, OnInit init, OnUpdate update, OnCleanup cleanup) {
  ASSERT(width > 0 && height > 0 && init && update && cleanup);
  printf("Hello MacOS!");

  copyStringFromCStr(&gApp.title, title);
  gApp.width = width;
  gApp.height = height;

  NSBundle *mainBundle = [NSBundle mainBundle];
  NSLog(@"Arch: %@", mainBundle.executableArchitectures);
  NSLog(@"Exe path: %@", mainBundle.executablePath);
  NSLog(@"Exe url: %@", mainBundle.executableURL);

  AppDelegate *appDelegate = [[AppDelegate alloc] init];
  [[NSApplication sharedApplication] setDelegate:appDelegate];
  int returnVal = NSApplicationMain(argc, (const char *_Nonnull *_Nonnull)argv);

  destroyString(&gApp.title);

  return returnVal;
}