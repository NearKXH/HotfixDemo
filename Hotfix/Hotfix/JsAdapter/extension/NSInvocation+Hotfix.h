//
//  NSInvocation+Hotfix.h
//  Hotfix
//
//  Created by nate on 2020/12/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JSValue;
@class JSContext;
@interface NSInvocation (Hotfix)

/// 获取入参
/// @param jsContext JSContext 用于设置 JSValue
/// @return 返回数组，当 jsContext 不为空时类型为 JSValue；为空时，则为对应 NSObject 类型
- (NSArray *)hf_getArguments:(JSContext *)jsContext;


/// 获取返参
/// @param jsContext jsContext JSContext 用于设置 JSValue
- (nullable JSValue *)hf_getReturnValue:(JSContext *)jsContext;


@end

NS_ASSUME_NONNULL_END
