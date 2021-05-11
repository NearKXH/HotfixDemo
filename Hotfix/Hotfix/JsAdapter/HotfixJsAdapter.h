//
//  HotfixJsAdapter.h
//  Hotfix
//
//  Created by nate on 2020/11/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HotfixJsAdapter : NSObject

- (void)runJS:(NSString *)js completion:(nullable void (^)(BOOL succeed))completion;

@end

NS_ASSUME_NONNULL_END
