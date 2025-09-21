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
    NSString *htmlUrl = config[@"htmlUrl"] ?: @"";
    if (htmlUrl.length == 0) {
      // Native integration default source
      htmlUrl = @"https://httpbin.org/html";
    }

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
       "};"
       "window.NupcoVOC.onEvent = function(name, data){"
       "  try { data = (data==null? '' : String(data)); } catch(e){ data=''; }"
       "  window.webkit.messageHandlers.NupcoVOC.postMessage({action:String(name||'event'),data:data});"
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

    void (^loadNativeHtml)(void) = ^{
      NSString *nativeHtml = @"<!doctype html><html><head><meta charset=\"utf-8\"/>"
                            @"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>"
                            @"<title>Nupco VOC</title>"
                            @"<style>body{font-family:-apple-system,Helvetica,Arial,sans-serif;padding:16px}"
                            @"button{padding:10px 16px;margin:8px;border:0;border-radius:8px}"
                            @".primary{background:#1976d2;color:#fff}.danger{background:#e53935;color:#fff}</style>"
                            @"</head><body>"
                            @"<h2>تقييم الخدمة</h2>"
                            @"<p>برجاء إدخال تقييمك وتعليقك ثم اضغط إرسال.</p>"
                            @"<label>التقييم (1-5): <input id=\"rating\" type=\"number\" min=\"1\" max=\"5\"/></label>"
                            @"<br/><label>التعليق:<br/><textarea id=\"fb\" rows=\"4\" style=\"width:100%\"></textarea></label>"
                            @"<div><button class=\"danger\" onclick=\"NupcoVOC.onCancel()\">إلغاء</button>"
                            @"<button class=\"primary\" onclick=\"(function(){var r=document.getElementById('rating').value;var t=document.getElementById('fb').value;"
                            @"var p=JSON.stringify({rating:r,feedback:t,timestamp:Date.now()});NupcoVOC.onSubmit(p)})()\">إرسال</button></div>"
                            @"</body></html>";
      [web loadHTMLString:nativeHtml baseURL:nil];
    };

    if (htmlUrl.length > 0) {
      NSURL *u = [NSURL URLWithString:htmlUrl];
      if (u) {
        [[[NSURLSession sharedSession] dataTaskWithURL:u completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (data && !error) {
              NSString *fetched = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
              if (fetched.length > 0) { [web loadHTMLString:fetched baseURL:nil]; }
              else { loadNativeHtml(); }
            } else { loadNativeHtml(); }
          });
        }] resume];
      } else {
        loadNativeHtml();
      }
    } else {
      loadNativeHtml();
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


