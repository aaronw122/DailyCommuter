//
//  FavoritesBridge.m
//  DailyCommuter
//
//  Created by Aaron Williams on 8/16/25.
//

// FavoritesBridge.m
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(FavoritesBridge, NSObject)

RCT_EXTERN_METHOD(saveFavorites:(NSString *)dtosJson
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
