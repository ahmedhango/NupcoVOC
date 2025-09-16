#import "NupcoVOCModule.h"
#import <WebKit/WebKit.h>
#import <React/RCTLog.h>

@interface NupcoVOCModule () <WKScriptMessageHandler>
@property (nonatomic, weak) UIViewController *presentedVC;
@end

@implementation NupcoVOCModule
RCT_EXPORT_MODULE(NupcoVOCModule);

- (NSArray<NSString *> *)supportedEvents { return @[@"NupcoVOCEvent"]; }
- (void)startObserving {}
- (void)stopObserving {}

RCT_EXPORT_METHOD(open:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *url = config[@"url"] ?: @"";
    NSString *html = config[@"html"] ?: @"";

    UIViewController *root = UIApplication.sharedApplication.delegate.window.rootViewController;

    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    [cfg.userContentController addScriptMessageHandler:self name:@"NupcoVOC"];

    NSString *bridgeJS =
      @"window.NupcoVOC = window.NupcoVOC || {};"
       "window.NupcoVOC.onSubmit = function(p){"
       "  window.webkit.messageHandlers.NupcoVOC.postMessage({action:'submit',data:String(p||'')});"
       "};"
       "window.NupcoVOC.onCancel = function(){"
       "  window.webkit.messageHandlers.NupcoVOC.postMessage({action:'cancel'});"
       "};";
    WKUserScript *script = [[WKUserScript alloc] initWithSource:bridgeJS
                                                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                              forMainFrameOnly:NO];
    [cfg.userContentController addUserScript:script];

    WKWebView *web = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];

    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor whiteColor];
    web.frame = vc.view.bounds;
    web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:web];
    vc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(_close)];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    self.presentedVC = nav;

    if (html.length) {
      [web loadHTMLString:html baseURL:nil];
    } else if (url.length) {
      NSURL *u = [NSURL URLWithString:url];
      if (u) [web loadRequest:[NSURLRequest requestWithURL:u]];
    }

    [root presentViewController:nav animated:YES completion:^{ resolve(@YES); }];
  });
}

- (void)_close {
  UIViewController *root = UIApplication.sharedApplication.delegate.window.rootViewController;
  [root.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  if (![message.name isEqualToString:@"NupcoVOC"]) return;

  NSDictionary *payload = ([message.body isKindOfClass:NSDictionary.class] ? message.body : @{}) ?: @{};
  NSString *action = payload[@"action"] ?: @"event";
  NSString *data = [payload[@"data"] isKindOfClass:NSString.class] ? payload[@"data"] : @"";

  [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": action, @"data": data }];

  if ([action isEqualToString:@"submit"] || [action isEqualToString:@"cancel"]) {
    [self _close];
  }
}
@end


