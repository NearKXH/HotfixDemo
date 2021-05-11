//
//  HotfixBlockExtension.h
//  Hotfix
//
//  Created by nate on 2021/1/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kHotfix_Invocation_Block_IsBlock = @"_hf_v_isBlock";

@class JSValue;

/// 查询block是否为js hook block
/// @param block block
extern JSValue * _Nullable Hotfix_Block_HookJs(id block);

/// 对JsBlock解包
/// @param jsVal jsVal
extern id Hotfix_Block_Decode(JSValue *jsVal);

/// 注册方法签名
extern NSDictionary<NSString *, NSArray *> * Hotfix_Block_TypeSignatureDict(void);


NS_ASSUME_NONNULL_END
