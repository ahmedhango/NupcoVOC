
#import "NupcoVOCModule.h"
#import <WebKit/WebKit.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

@interface NupcoVOCModule () <WKScriptMessageHandler>
@property (nonatomic, weak) UIViewController *presentedVC;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKUserContentController *userContentController;
@end

@implementation NupcoVOCModule

RCT_EXPORT_MODULE(NupcoVOCModule);

- (NSArray<NSString *> *)supportedEvents { return @[@"NupcoVOCEvent"]; }
- (void)startObserving {}
- (void)stopObserving {}

RCT_EXPORT_METHOD(open:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    @try {
      NSString *url     = [config[@"url"] isKindOfClass:NSString.class] ? config[@"url"] : @"";
  NSString *html    = [config[@"html"] isKindOfClass:NSString.class] ? config[@"html"] : @"";
  NSString *htmlUrl = [config[@"htmlUrl"] isKindOfClass:NSString.class] ? config[@"htmlUrl"] : @"";
  NSNumber *useDefault = [config objectForKey:@"useDefaultHtmlUrl"];
  if (html.length == 0 && url.length == 0 && htmlUrl.length == 0 && [useDefault boolValue]) {
    htmlUrl = @"https://httpbin.org/html";
  }

      UIViewController *root = RCTPresentedViewController() ?: UIApplication.sharedApplication.delegate.window.rootViewController;
      if (!root) { resolve(@(NO)); return; }

      WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
      WKPreferences *prefs = [WKPreferences new];
      prefs.javaScriptEnabled = YES;
      cfg.preferences = prefs;

      self.userContentController = [WKUserContentController new];
      [self.userContentController addScriptMessageHandler:self name:@"NupcoVOC"];

      NSString *bridgeJS =
      @"window.NupcoVOC = window.NupcoVOC || {};"
       "window.NupcoVOC.onSubmit = function(p){"
       "  try{p=String(p||'')}catch(e){p=''};"
       "  window.webkit.messageHandlers.NupcoVOC.postMessage({action:'submit',data:p});"
       "};"
       "window.NupcoVOC.onCancel = function(){"
       "  window.webkit.messageHandlers.NupcoVOC.postMessage({action:'cancel'});"
       "};"
       "window.NupcoVOC.onEvent = function(name,data){"
       "  try{data=(data==null?'':String(data))}catch(e){data=''};"
       "  window.webkit.messageHandlers.NupcoVOC.postMessage({action:String(name||'event'),data:data});"
       "};";

      WKUserScript *script = [[WKUserScript alloc] initWithSource:bridgeJS
                                                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                forMainFrameOnly:YES];
      [self.userContentController addUserScript:script];
      cfg.userContentController = self.userContentController;

      self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];

      UIViewController *vc = [UIViewController new];
      vc.view.backgroundColor = [UIColor whiteColor];

      self.webView.frame = vc.view.bounds;
      self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
      [vc.view addSubview:self.webView];

      vc.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                      target:self
                                                      action:@selector(_close)];

      UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
      self.presentedVC = nav;

      if (html.length > 0) {
        [self.webView loadHTMLString:html baseURL:nil];
      } else if (url.length > 0) {
        NSURL *u = [NSURL URLWithString:url];
        if (u) {
          NSURLRequest *req = [NSURLRequest requestWithURL:u
                                               cachePolicy:NSURLRequestUseProtocolCachePolicy
                                           timeoutInterval:15.0];
          [self.webView loadRequest:req];
        } else {
          [self _loadFallbackHTML];
        }
      } else if (htmlUrl.length > 0) {
        NSURL *u = [NSURL URLWithString:htmlUrl];
        if (u) {
          NSURLSessionDataTask *task =
          [[NSURLSession sharedSession] dataTaskWithURL:u
                                      completionHandler:^(NSData * _Nullable data,
                                                          NSURLResponse * _Nullable response,
                                                          NSError * _Nullable error)
           {
             dispatch_async(dispatch_get_main_queue(), ^{
               if (data && !error) {
                 NSString *fetched = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                 if (fetched.length > 0) {
                   [self.webView loadHTMLString:fetched baseURL:nil];
                 } else {
                   [self _loadFallbackHTML];
                 }
               } else {
                 [self _loadFallbackHTML];
               }
             });
           }];
          [task resume];
        } else {
          [self _loadFallbackHTML];
        }
      } else {
        [self _loadFallbackHTML];
      }

      [root presentViewController:nav animated:YES completion:^{ resolve(@(YES)); }];
    }
    @catch (NSException *ex) {
      reject(@"ERR_OPEN", ex.reason, nil);
    }
  });
}

- (void)_loadFallbackHTML
{
  static NSString *nativeHtml;
  if (!nativeHtml) {
    nativeHtml =
    @"<!doctype html><html><head><meta charset=\\"utf-8\\"/>"
     "<meta name=\\"viewport\\" content=\\"width=device-width, initial-scale=1\\"/>"
     "<title>Nupco VOC</title>"
     "<style>body{font-family:-apple-system,Helvetica,Arial,sans-serif;padding:16px}"
     "button{padding:10px 16px;margin:8px;border:0;border-radius:8px}"
     ".primary{background:#1976d2;color:#fff}.danger{background:#e53935;color:#fff}</style>"
     "</head><body>"
     "<h2>تقييم الخدمة</h2>"
     "<p>برجاء إدخال تقييمك وتعليقك ثم اضغط إرسال.</p>"
     "<label>التقييم (1-5): <input id=\\"rating\\" type=\\"number\\" min=\\"1\\" max=\\"5\\"/></label>"
     "<br/><label>التعليق:<br/><textarea id=\\"fb\\" rows=\\"4\\" style=\\"width:100%\\"></textarea></label>"
     "<div><button class=\\"danger\\" onclick=\\"NupcoVOC.onCancel()\\">إلغاء</button>"
     "<button class=\\"primary\\" onclick=\\"(function(){var r=document.getElementById('rating').value;"
     "var t=document.getElementById('fb').value;"
     "var p=JSON.stringify({rating:r,feedback:t,timestamp:Date.now()});NupcoVOC.onSubmit(p)})()\\">إرسال</button></div>"
     "</body></html>";
  }
  [self.webView loadHTMLString:nativeHtml baseURL:nil];
}

- (void)_cleanupBridge
{
  @try {
    [self.userContentController removeScriptMessageHandlerForName:@"NupcoVOC"];
  } @catch (__unused NSException *ex) {}
  self.userContentController = nil;
  self.webView = nil;
}

- (void)_close
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = self.presentedVC ?: RCTPresentedViewController();
    [presenter dismissViewControllerAnimated:YES completion:nil];
    [self _cleanupBridge];
    self.presentedVC = nil;
  });
}

- (void)dealloc
{
  [self _cleanupBridge];
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
  if (![message.name isEqualToString:@"NupcoVOC"]) return;

  NSDictionary *payload = ([message.body isKindOfClass:NSDictionary.class] ? message.body : @{}) ?: @{};
  NSString *action = [payload[@"action"] isKindOfClass:NSString.class] ? payload[@"action"] : @"event";
  NSString *data   = [payload[@"data"]   isKindOfClass:NSString.class] ? payload[@"data"]   : @"";

  [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": action, @"data": data }];

  if ([action isEqualToString:@"submit"] || [action isEqualToString:@"cancel"]) {
    [self _close];
  }
}

@end
