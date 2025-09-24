
#import "NupcoVOCModule.h"
#import <WebKit/WebKit.h>
#import <React/RCTUtils.h>

static NSString * sToken;
static NSString * sID;
static NSString * const kAuthEndpoint = @"https://example.com/api/auth";
static NSString * const kDataEndpoint = @"https://example.com/api/inline-html";

@interface NupcoVOCModule () <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic, weak) UIViewController *presentedVC;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL isPresenting;
@property (nonatomic, strong) NSDictionary *extraHeaders;
@end

@implementation NupcoVOCModule
RCT_EXPORT_MODULE(NupcoVOCModule);
- (void)close
{
  [self _close];
}

RCT_EXPORT_METHOD(isOpen:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(@(self.isPresenting));
}

- (NSArray<NSString *> *)supportedEvents { return @[@"NupcoVOCEvent"]; }
- (void)startObserving {}
- (void)stopObserving {}

RCT_EXPORT_METHOD(initialize:(NSDictionary *)cfg
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    sToken = [cfg[@"token"] isKindOfClass:NSString.class] ? cfg[@"token"] : @"";
    sID    = [cfg[@"id"] isKindOfClass:NSString.class] ? cfg[@"id"] : @"";
    self.isInitialized = (sToken.length > 0);
    resolve(@(self.isInitialized));
  } @catch (NSException *ex) { reject(@"ERR_INIT", ex.reason, nil); }
}

RCT_EXPORT_METHOD(open:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (self.isPresenting) { resolve(@(NO)); return; }
  if (!self.isInitialized) {
    dispatch_async(dispatch_get_main_queue(), ^{
      UIViewController *presenter = RCTPresentedViewController() ?: UIApplication.sharedApplication.delegate.window.rootViewController;
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self t:@"error_title"] message:[self t:@"invalid_token"] preferredStyle:UIAlertControllerStyleAlert];
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
  self.extraHeaders = [config[@"headers"] isKindOfClass:NSDictionary.class] ? config[@"headers"] : nil;

  if (html.length > 0 || url.length > 0 || htmlUrl.length > 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.isPresenting = YES;
      [self presentWithHTML:html url:url htmlUrl:htmlUrl resolve:resolve];
    });
    return;
  }

  // Native-only flow: AUTH then DATA, fetch first, THEN present with ready HTML.
  NSString *authEndpoint = [config objectForKey:@"authEndpoint"] ?: kAuthEndpoint;
  NSString *dataEndpoint = [config objectForKey:@"dataEndpoint"] ?: kDataEndpoint;
  NSNumber *timeoutMsNum = [config objectForKey:@"timeoutMs"] ?: @(8000);
  NSNumber *retriesNum   = [config objectForKey:@"retries"] ?: @(1);

  // Helper block to proceed with data fetch after optional auth
  void (^startDataFetch)(void) = ^{
    NSURL *dataURL = [NSURL URLWithString:dataEndpoint];
    NSMutableURLRequest *dataReq = [NSMutableURLRequest requestWithURL:dataURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MAX(8.0, timeoutMsNum.doubleValue/1000.0)];
    dataReq.HTTPMethod = @"POST";
    [dataReq setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
    [dataReq setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (sToken.length > 0) [dataReq setValue:[@"Bearer " stringByAppendingString:sToken] forHTTPHeaderField:@"Authorization"];
    [dataReq setValue:(sToken ?: @"") forHTTPHeaderField:@"X-Auth-Token"];
    // apply custom headers
    if ([self.extraHeaders isKindOfClass:NSDictionary.class]) {
      [self.extraHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key isKindOfClass:NSString.class] && [obj isKindOfClass:NSString.class]) {
          [dataReq setValue:(NSString*)obj forHTTPHeaderField:(NSString*)key];
        }
      }];
    }
    NSString *dataBody = [NSString stringWithFormat:@"{\"id\":\"%@\"}", sID ?: @"" ];
    dataReq.HTTPBody = [dataBody dataUsingEncoding:NSUTF8StringEncoding];

    void (^startDataTask)(int) = ^(int attemptsLeft) {
      NSURLSessionDataTask *dt = [[NSURLSession sharedSession] dataTaskWithRequest:dataReq completionHandler:^(NSData * _Nullable data2, NSURLResponse * _Nullable response2, NSError * _Nullable error2) {
      NSString *htmlReady = @"";
      if (data2 && !error2) {
        NSString *s = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
        if (s.length > 0) htmlReady = s;
      }
        if (htmlReady.length == 0 && attemptsLeft > 0) { startDataTask(attemptsLeft - 1); return; }
        dispatch_async(dispatch_get_main_queue(), ^{
          if (htmlReady.length == 0) {
            UIViewController *presenter = RCTPresentedViewController() ?: UIApplication.sharedApplication.delegate.window.rootViewController;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self t:@"load_failed"] message:nil preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [presenter presentViewController:alert animated:YES completion:nil];
            resolve(@(NO));
          } else {
            self.isPresenting = YES;
            [self presentWithHTML:htmlReady url:@"" htmlUrl:@"" resolve:resolve];
          }
        });
      }];
      [dt resume];
    };
    startDataTask(MAX(0, retriesNum.intValue));
  };

  // If authEndpoint is provided, perform AUTH first, else skip to data fetch
  if (authEndpoint && authEndpoint.length > 0) {
    NSURL *authURL = [NSURL URLWithString:authEndpoint];
    NSMutableURLRequest *authReq = [NSMutableURLRequest requestWithURL:authURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MAX(8.0, timeoutMsNum.doubleValue/1000.0)];
    authReq.HTTPMethod = @"POST";
    [authReq setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [authReq setValue:@"application/json,text/plain,*/*" forHTTPHeaderField:@"Accept"];
    // apply custom headers
    if ([self.extraHeaders isKindOfClass:NSDictionary.class]) {
      [self.extraHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key isKindOfClass:NSString.class] && [obj isKindOfClass:NSString.class]) {
          [authReq setValue:(NSString*)obj forHTTPHeaderField:(NSString*)key];
        }
      }];
    }
    NSString *authBody = [NSString stringWithFormat:@"{\"token\":\"%@\",\"id\":\"%@\"}", sToken ?: @"", sID ?: @"" ];
    authReq.HTTPBody = [authBody dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *authTask = [[NSURLSession sharedSession] dataTaskWithRequest:authReq completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
      BOOL ok = NO;
      if (data && !error) {
        NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        if ([[resp lowercaseString] containsString:@"ok"] || [resp containsString:@"تمام"]) ok = YES;
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
          UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self t:@"auth_failed"] message:nil preferredStyle:UIAlertControllerStyleAlert];
          [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
          [presenter presentViewController:alert animated:YES completion:nil];
        });
        resolve(@(NO));
        return;
      }
      startDataFetch();
    }];
    [authTask resume];
  } else {
    startDataFetch();
  }
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
  // Floating close button
  UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [closeBtn setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
  closeBtn.tintColor = [UIColor blackColor];
  closeBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
  closeBtn.layer.cornerRadius = 22;
  closeBtn.contentEdgeInsets = UIEdgeInsetsMake(8, 8, 8, 8);
  closeBtn.frame = CGRectMake(vc.view.bounds.size.width - 56, 20 + 8, 44, 44);
  closeBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
  [closeBtn addTarget:self action:@selector(_close) forControlEvents:UIControlEventTouchUpInside];
  [vc.view addSubview:closeBtn];
  self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  self.spinner.center = vc.view.center;
  self.spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
  [vc.view addSubview:self.spinner];
  [self.spinner startAnimating];
  vc.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(_close)];

  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  self.presentedVC = nav;

  if (html.length > 0) {
    [self.webView loadHTMLString:html baseURL:nil];
  } else if (url.length > 0) {
    NSURL *u = [NSURL URLWithString:url];
    if (u) {
      NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
      if ([self.extraHeaders isKindOfClass:NSDictionary.class]) {
        [self.extraHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
          if ([key isKindOfClass:NSString.class] && [obj isKindOfClass:NSString.class]) {
            [req setValue:(NSString*)obj forHTTPHeaderField:(NSString*)key];
          }
        }];
      }
      [self.webView loadRequest:req];
    }
  } else if (htmlUrl.length > 0) {
    NSURL *u = [NSURL URLWithString:htmlUrl];
    if (u) {
      NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
      if ([self.extraHeaders isKindOfClass:NSDictionary.class]) {
        [self.extraHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
          if ([key isKindOfClass:NSString.class] && [obj isKindOfClass:NSString.class]) {
            [req setValue:(NSString*)obj forHTTPHeaderField:(NSString*)key];
          }
        }];
      }
      [self.webView loadRequest:req];
    }
  } else {
    [self.webView loadHTMLString:@"" baseURL:nil];
  }

  [root presentViewController:nav animated:YES completion:^{ resolve(@(YES)); }];
  [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": @"opened", @"data": @"" }];

  [self.webView addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:nil];
  self.webView.navigationDelegate = self;
}

// Observe loading to toggle spinner
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
  if (object == self.webView && [keyPath isEqualToString:@"loading"]) {
    BOOL loading = self.webView.isLoading;
    if (loading) { [self.spinner startAnimating]; self.spinner.hidden = NO; }
    else { [self.spinner stopAnimating]; self.spinner.hidden = YES; }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

// WKNavigationDelegate: emit loaded/error
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": @"loaded", @"data": @"" }];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": @"error", @"data": error.localizedDescription ?: @"" }];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": @"error", @"data": error.localizedDescription ?: @"" }];
}

- (void)_close {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = self.presentedVC ?: RCTPresentedViewController();
    [presenter dismissViewControllerAnimated:YES completion:nil];
    self.presentedVC = nil;
    self.webView = nil;
    self.isPresenting = NO;
    [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": @"closed", @"data": @"" }];
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

// i18n helper
- (NSString *)t:(NSString *)key {
  NSString *lang = [NSLocale preferredLanguages].firstObject ?: @"en";
  BOOL ar = [lang hasPrefix:@"ar"];
  if (ar) {
    if ([key isEqualToString:@"error_title"]) return @"خطأ";
    if ([key isEqualToString:@"invalid_token"]) return @"رمز/معرّف غير صالح";
    if ([key isEqualToString:@"auth_failed"]) return @"فشل التحقق";
    if ([key isEqualToString:@"load_failed"]) return @"فشل تحميل البيانات";
  }
  if ([key isEqualToString:@"error_title"]) return @"Error";
  if ([key isEqualToString:@"invalid_token"]) return @"Invalid token/id";
  if ([key isEqualToString:@"auth_failed"]) return @"Auth failed";
  if ([key isEqualToString:@"load_failed"]) return @"Failed to load data";
  return key;
}

@end
