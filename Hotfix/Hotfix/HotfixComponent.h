//
//  HotfixComponent.h
//  Hotfix
//
//  Created by nate on 2021/1/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HotfixComponent : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

// register component at root application:didFinishLaunchingWithOptions:
+ (void)registerComponent;


@end

NS_ASSUME_NONNULL_END
