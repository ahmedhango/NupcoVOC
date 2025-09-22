
#import "NupcoVOCModule.h"
#import <WebKit/WebKit.h>
#import <React/RCTUtils.h>

static NSString * const kToken        = @"1111";
static NSString * const kID           = @"12";
static NSString * const kAuthEndpoint = @"https://example.com/api/auth";
static NSString * const kDataEndpoint = @"https://example.com/api/inline-html";

@interface NupcoVOCModule () <WKScriptMessageHandler>
@property (nonatomic, weak) UIViewController *presentedVC;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, assign) BOOL isInitialized;
@end

@implementation NupcoVOCModule
RCT_EXPORT_MODULE(NupcoVOCModule);

- (NSArray<NSString *> *)supportedEvents { return @[@"NupcoVOCEvent"]; }
- (void)startObserving {}
- (void)stopObserving {}

RCT_EXPORT_METHOD(initialize:(NSDictionary *)cfg
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    NSString *token = [cfg[@"token"] isKindOfClass:NSString.class] ? cfg[@"token"] : @"";
    NSString *rid   = [cfg[@"id"] isKindOfClass:NSString.class] ? cfg[@"id"] : @"";
    BOOL ok = [token isEqualToString:kToken] && [rid isEqualToString:kID];
    self.isInitialized = ok;
    resolve(@(ok));
  } @catch (NSException *ex) { reject(@"ERR_INIT", ex.reason, nil); }
}

RCT_EXPORT_METHOD(open:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (!self.isInitialized) {
    dispatch_async(dispatch_get_main_queue(), ^{
      UIViewController *presenter = RCTPresentedViewController() ?: UIApplication.sharedApplication.delegate.window.rootViewController;
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Invalid token/id" preferredStyle:UIAlertControllerStyleAlert];
      [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
      [presenter presentViewController:alert animated:YES completion:nil];
    });
    resolve(@(NO));
    return;
  }

  // If JS provided html/url/htmlUrl → just present it (display only)
  NSString *url  = [config[@"url"] isKindOfClass:NSString.class] ? config[@"url"] : @"";
  NSString *html = [config[@"html"] isKindOfClass:NSString.class] ? config[@"html"] : @"";
  NSString *htmlUrl = [config[@"htmlUrl"] isKindOfClass:NSString.class] ? config[@"htmlUrl"] : @"";

  if (html.length > 0 || url.length > 0 || htmlUrl.length > 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self presentWithHTML:html url:url htmlUrl:htmlUrl resolve:resolve];
    });
    return;
  }

  // Native-only flow: AUTH then DATA, fetch first, THEN present with ready HTML.
  NSURL *authURL = [NSURL URLWithString:kAuthEndpoint];
  NSMutableURLRequest *authReq = [NSMutableURLRequest requestWithURL:authURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:8.0];
  authReq.HTTPMethod = @"POST";
  [authReq setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
  [authReq setValue:@"application/json,text/plain,*/*" forHTTPHeaderField:@"Accept"];
  NSString *authBody = [NSString stringWithFormat:@"{\"token\":\"%@\",\"id\":\"%@\"}", kToken, kID];
  authReq.HTTPBody = [authBody dataUsingEncoding:NSUTF8StringEncoding];

  NSURLSessionDataTask *authTask = [[NSURLSession sharedSession] dataTaskWithRequest:authReq completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    BOOL ok = NO;
    if (data && !error) {
      NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
      if ([resp containsString:@"تمام"] || [[resp lowercaseString] isEqualToString:@"ok"]) ok = YES;
      if (!ok) {
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([obj isKindOfClass:NSDictionary.class]) {
          id ov = obj[@"ok"]; id st = obj[@"status"];
          if (([ov isKindOfClass:NSNumber.class] && [(NSNumber*)ov boolValue]) ||
              ([st isKindOfClass:NSString.class] && [[(NSString*)st lowercaseString] isEqualToString:@"ok"])) ok = YES;
        }
      }
    }
    if (!ok) {
      dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = RCTPresentedViewController() ?: UIApplication.sharedApplication.delegate.window.rootViewController;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Auth failed" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
      });
      resolve(@(NO));
      return;
    }

    // Fetch DATA (HTML) now
    NSURL *dataURL = [NSURL URLWithString:kDataEndpoint];
    NSMutableURLRequest *dataReq = [NSMutableURLRequest requestWithURL:dataURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:8.0];
    dataReq.HTTPMethod = @"POST";
    [dataReq setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
    [dataReq setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [dataReq setValue:kToken forHTTPHeaderField:@"X-Auth-Token"];
    NSString *dataBody = [NSString stringWithFormat:@"{\"id\":\"%@\"}", kID];
    dataReq.HTTPBody = [dataBody dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:dataReq completionHandler:^(NSData * _Nullable data2, NSURLResponse * _Nullable response2, NSError * _Nullable error2) {
      NSString *htmlReady = @"";
      if (data2 && !error2) {
        NSString *s = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
        if (s.length > 0) htmlReady = s;
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        if (htmlReady.length == 0) {
          UIViewController *presenter = RCTPresentedViewController() ?: UIApplication.sharedApplication.delegate.window.rootViewController;
          UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Failed to load data" message:nil preferredStyle:UIAlertControllerStyleAlert];
          [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
          [presenter presentViewController:alert animated:YES completion:nil];
          resolve(@(NO));
        } else {
          [self presentWithHTML:htmlReady url:@"" htmlUrl:@"" resolve:resolve];
        }
      });
    }];
    [dataTask resume];
  }];
  [authTask resume];
}

- (void)presentWithHTML:(NSString *)html url:(NSString *)url htmlUrl:(NSString *)htmlUrl resolve:(RCTPromiseResolveBlock)resolve {
  UIViewController *root = RCTPresentedViewController() ?: UIApplication.sharedApplication.delegate.window.rootViewController;
  if (!root) { resolve(@(NO)); return; }

  WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
  WKUserContentController *uc = [WKUserContentController new];
  [uc addScriptMessageHandler:self name:@"NupcoVOC"];
  NSString *bridgeJS =
    @"window.NupcoVOC = window.NupcoVOC || {};"
     "window.NupcoVOC.onSubmit = function(p){"
     "  window.webkit.messageHandlers.NupcoVOC.postMessage({action:'submit',data:String(p||'')});"
     "};"
     "window.NupcoVOC.onCancel = function(){"
     "  window.webkit.messageHandlers.NupcoVOC.postMessage({action:'cancel'});"
     "};";
  WKUserScript *script = [[WKUserScript alloc] initWithSource:bridgeJS injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
  [uc addUserScript:script];
  cfg.userContentController = uc;

  self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];
  UIViewController *vc = [UIViewController new];
  vc.view.backgroundColor = [UIColor whiteColor];
  self.webView.frame = vc.view.bounds;
  self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [vc.view addSubview:self.webView];
  vc.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(_close)];

  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  self.presentedVC = nav;

  if (html.length > 0) {
    [self.webView loadHTMLString:html baseURL:nil];
  } else if (url.length > 0) {
    NSURL *u = [NSURL URLWithString:url];
    if (u) [self.webView loadRequest:[NSURLRequest requestWithURL:u]];
  } else if (htmlUrl.length > 0) {
    NSURL *u = [NSURL URLWithString:htmlUrl];
    if (u) [self.webView loadRequest:[NSURLRequest requestWithURL:u]];
  } else {
    [self.webView loadHTMLString:@"" baseURL:nil];
  }

  [root presentViewController:nav animated:YES completion:^{ resolve(@(YES)); }];
}

- (void)_close {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = self.presentedVC ?: RCTPresentedViewController();
    [presenter dismissViewControllerAnimated:YES completion:nil];
    self.presentedVC = nil;
    self.webView = nil;
  });
}

#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
  if (![message.name isEqualToString:@"NupcoVOC"]) return;
  NSDictionary *payload = ([message.body isKindOfClass:NSDictionary.class] ? message.body : @{}) ?: @{};
  NSString *action = [payload[@"action"] isKindOfClass:NSString.class] ? payload[@"action"] : @"event";
  NSString *data   = [payload[@"data"]   isKindOfClass:NSString.class] ? payload[@"data"]   : @"";
  [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": action, @"data": data }];
  if ([action isEqualToString:@"submit"] || [action isEqualToString:@"cancel"]) [self _close];
}

@end
