#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>

@interface NupcoVOCModule : RCTEventEmitter <RCTBridgeModule>
- (void)close;
- (void)isOpen:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject;
@end
