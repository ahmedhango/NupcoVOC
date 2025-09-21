
#import "NupcoVOCModule.h"
#import <WebKit/WebKit.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

@interface NupcoVOCModule () <WKScriptMessageHandler>
@property (nonatomic, weak) UIViewController *presentedVC;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKUserContentController *userContentController;
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
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @try {
      NSString *token = [cfg[@"token"] isKindOfClass:NSString.class] ? cfg[@"token"] : @"";
      NSString *rid   = [cfg[@"id"] isKindOfClass:NSString.class] ? cfg[@"id"] : @"";
      
      // First check if token and id are the correct values
      if (![token isEqualToString:@"1111"] || ![rid isEqualToString:@"12"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          reject(@"ERR_INIT_FAILED", @"Invalid token or ID", nil);
        });
        return;
      }
      
      // If token and id are correct, send to endpoint and accept any response
      NSURL *url = [NSURL URLWithString:@"https://httpbin.org/post"];
      NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
      [request setHTTPMethod:@"POST"];
      [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
      
      NSDictionary *payload = @{
        @"token": token ?: @"",
        @"id": rid ?: @""
      };
      
      NSError *jsonError;
      NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
      if (jsonError) {
        NSLog(@"JSON serialization error: %@", jsonError);
        dispatch_async(dispatch_get_main_queue(), ^{
          resolve(@{@"success": @YES, @"message": @"Initialization successful"});
        });
        return;
      }
      
      [request setHTTPBody:jsonData];
      
      // Synchronous request for simplicity (in production use async)
      NSURLResponse *response;
      NSError *error;
      NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
      
      if (error) {
        NSLog(@"Network error: %@", error);
      }
      
      NSLog(@"Valid token and id, response received");
      
      dispatch_async(dispatch_get_main_queue(), ^{
        resolve(@{@"success": @YES, @"message": @"Initialization successful"});
      });
    } @catch (NSException *ex) {
      dispatch_async(dispatch_get_main_queue(), ^{
        reject(@"ERR_INIT_EXCEPTION", ex.reason, nil);
      });
    }
  });
}

RCT_EXPORT_METHOD(open:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    @try {
      if (!self.isInitialized) {
        UIViewController *presenter = RCTPresentedViewController() ?: UIApplication.sharedApplication.delegate.window.rootViewController;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Invalid token/id" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
        resolve(@(NO));
        return;
      }

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

      WKUserScript *script = [[WKUserScript alloc] initWithSource:bridgeJS injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
      [self.userContentController addUserScript:script];

      if (self.isInitialized) {
        NSString *btnJS =
        @"(function(){"
         "var b=document.getElementById('nupco-init-btn');"
         "if(!b){b=document.createElement('button');b.id='nupco-init-btn';"
         "b.innerText='Init Alert';b.style.position='fixed';b.style.bottom='20px';b.style.right='20px';"
         "b.style.padding='12px 16px';b.style.border='0';b.style.borderRadius='8px';b.style.background='#1976d2';b.style.color='#fff';"
         "b.style.zIndex='2147483647';document.body.appendChild(b);}"
         "b.onclick=function(){ try{ window.NupcoVOC && window.NupcoVOC.onEvent('init_ok',''); }catch(e){} };"
         "})();";
        WKUserScript *btnScript = [[WKUserScript alloc] initWithSource:btnJS injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        [self.userContentController addUserScript:btnScript];
      }

      cfg.userContentController = self.userContentController;
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
        else { [self.webView loadHTMLString:@"" baseURL:nil]; }
      } else if (htmlUrl.length > 0) {
        NSURL *u = [NSURL URLWithString:htmlUrl];
        if (u) {
          NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:u completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
              if (data && !error) {
                NSString *fetched = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                [self.webView loadHTMLString:(fetched ?: @"") baseURL:nil];
              } else {
                [self.webView loadHTMLString:@"" baseURL:nil];
              }
            });
          }];
          [task resume];
        } else {
          [self.webView loadHTMLString:@"" baseURL:nil];
        }
      } else {
        [self.webView loadHTMLString:@"" baseURL:nil];
      }

      [root presentViewController:nav animated:YES completion:^{ resolve(@(YES)); }];
    } @catch (NSException *ex) {
      reject(@"ERR_OPEN", ex.reason, nil);
    }
  });
}

- (void)_cleanupBridge {
  @try { [self.userContentController removeScriptMessageHandlerForName:@"NupcoVOC"]; } @catch (__unused NSException *ex) {}
  self.userContentController = nil;
  self.webView = nil;
}

- (void)_close {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = self.presentedVC ?: RCTPresentedViewController();
    [presenter dismissViewControllerAnimated:YES completion:nil];
    [self _cleanupBridge];
    self.presentedVC = nil;
  });
}

- (void)dealloc { [self _cleanupBridge]; }

#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
  if (![message.name isEqualToString:@"NupcoVOC"]) return;
  NSDictionary *payload = ([message.body isKindOfClass:NSDictionary.class] ? message.body : @{}) ?: @{};
  NSString *action = [payload[@"action"] isKindOfClass:NSString.class] ? payload[@"action"] : @"event";
  NSString *data   = [payload[@"data"]   isKindOfClass:NSString.class] ? payload[@"data"]   : @"";
  [self sendEventWithName:@"NupcoVOCEvent" body:@{ @"action": action, @"data": data }];
  if ([action isEqualToString:@"init_ok"]) {
    UIViewController *presenter = self.presentedVC ?: RCTPresentedViewController();
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Initialized ✅" message:@"Token/ID validated" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
  }
  if ([action isEqualToString:@"submit"] || [action isEqualToString:@"cancel"]) [self _close];
}

@end
