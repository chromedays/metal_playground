#include "memory.c"
static float gScreenWidth = 1280;
static float gScreenHeight = 720;
#include "renderer.m"
#import <AppKit/AppKit.h>
#include <stdbool.h>
#include <stdio.h>

static const char *gWindowTitleBase = "Metal Playground";
static bool gRunning;

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
  NSString *launchPath = [NSBundle.mainBundle pathForResource:@"test"
                                                       ofType:nil];
  NSFileManager *filemgr;
  NSString *currentpath;

  filemgr = [[NSFileManager alloc] init];

  currentpath = [filemgr currentDirectoryPath];
  NSLog(@"haha %@", currentpath);
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