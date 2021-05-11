//
//  HotfixJsAdapter.m
//  Hotfix
//
//  Created by nate on 2020/11/21.
//

#import "HotfixJsAdapter.h"

#import <UIKit/UIKit.h>

#import <JavaScriptCore/JavaScriptCore.h>
#import <Aspects/Aspects.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "HotfixInvocationSetDefined.h"
#import "NSInvocation+Hotfix.h"
#import "HotfixBlockExtension.h"
#import "HotfixPropertyStoreMethod.h"

/// 空实现，用于添加方法 Impl
static void _hotfix_hookEmptySelectorImpl() {}

#pragma mark - Dispatch Once Object
// 用户缓存 dispatch_once 地址
@interface HotfixJsAdapterOnceObject : NSObject {
    @public
    dispatch_once_t _once;
}
@end

@implementation HotfixJsAdapterOnceObject
@end


#pragma mark - Property Defined
typedef NSString * const _Hotfix_PropertyKeyName;

/// 原子性，布尔值
static _Hotfix_PropertyKeyName _kHotfix_PropertyAttKey_Atomic = @"_hf_v_atomic";
/// 引用权限，字符串；
/// assign：基础数据类型，默认，不可修改；
/// strong：强引用对象，默认；weak：弱引用对象；copy：拷贝对象，对象实现 NSCopy 协议；
static _Hotfix_PropertyKeyName _kHotfix_PropertyAttKey_Role = @"_hf_v_role";

/** 以下属性类型暂不支持 */
/// 只读，布尔值
static _Hotfix_PropertyKeyName _kHotfix_PropertyAttKey_Readonly = @"_hf_v_readonly";
/// getter方法，字符串，必须符合方法命名
static _Hotfix_PropertyKeyName _kHotfix_PropertyAttKey_Getter = @"_hf_v_getter";
/// setter方法，字符串，必须符合方法命名
static _Hotfix_PropertyKeyName _kHotfix_PropertyAttKey_Setter = @"_hf_v_setter";
/// 类属性，布尔值
static _Hotfix_PropertyKeyName _kHotfix_PropertyAttKey_Class = @"_hf_v_class";

/// 属性引用类型
typedef NS_ENUM(NSUInteger, HotfixJsAdapterDynamicPropertyRole) {
    HotfixJsAdapterDynamicPropertyRoleDefault,
    HotfixJsAdapterDynamicPropertyRoleRetain = HotfixJsAdapterDynamicPropertyRoleDefault,
    HotfixJsAdapterDynamicPropertyRoleCopy,
    HotfixJsAdapterDynamicPropertyRoleWeak
};

// 属性类型参数
@interface HotfixJsAdapterDynamicProperty : NSObject
@property (nonatomic, strong) NSString *cls;    ///< 类名
@property (nonatomic, strong) NSString *name;   ///< 属性名
@property (nonatomic, strong) NSString *type;   ///< 类型

@property (nonatomic, assign) BOOL isObj;       ///< 是否对象类型

@property (nonatomic, assign) BOOL nonatomic;   ///< 原子性
@property (nonatomic, assign) HotfixJsAdapterDynamicPropertyRole role;  ///< 引用类型

@property (nonatomic, assign) BOOL readonly;                ///< 只读，暂不支持，默认为false
@property (nonatomic, assign) BOOL isClass;                 ///< 类方法，暂不支持，默认为false
@property (nonatomic, strong, nullable) NSString *getter;   ///< 自定义getter方法名，暂不支持，默认为nil
@property (nonatomic, strong, nullable) NSString *setter;   ///< 自定义setter方法名，暂不支持，默认为nil

+ (instancetype)propertyWithName:(NSString *)name cls:(NSString *)cls type:(NSString *)type att:(NSDictionary<_Hotfix_PropertyKeyName, id> *)att;

@end

@implementation HotfixJsAdapterDynamicProperty
+ (instancetype)propertyWithName:(NSString *)name cls:(NSString *)cls type:(NSString *)type att:(NSDictionary<_Hotfix_PropertyKeyName, id> *)att {
    HotfixJsAdapterDynamicProperty *property = [[HotfixJsAdapterDynamicProperty alloc] init];
    property.name = name;
    property.cls = cls;
    property.type = type;
    
    property.isObj = [type isEqualToString:@"id"] || [type isEqualToString:@"Class"];
    
    property.nonatomic = ![att[_kHotfix_PropertyAttKey_Atomic] boolValue];
    if (property.isObj) {
        NSString *role = [att[_kHotfix_PropertyAttKey_Role] description];
        if ([role isEqualToString:@"weak"]) {
            property.role = HotfixJsAdapterDynamicPropertyRoleWeak;
        } else if ([role isEqualToString:@"copy"]) {
            property.role = HotfixJsAdapterDynamicPropertyRoleCopy;
        } else {
            property.role = HotfixJsAdapterDynamicPropertyRoleRetain;
        }
        
    } else {
        property.role = HotfixJsAdapterDynamicPropertyRoleDefault;
        
    }
    
    // 以下属性暂不支持
//    property.readonly = [att[_kHotfix_PropertyAttKey_Readonly] boolValue];
//    property.isClass = [att[_kHotfix_PropertyAttKey_Class] boolValue];
//    property.getter = [att[_kHotfix_PropertyAttKey_Getter] stringValue];
//    property.setter = [att[_kHotfix_PropertyAttKey_Setter] stringValue];
    
    return property;
}
@end


#pragma mark -

/**
 方法签名参考：
 
 https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-SW1
 */


// JSON.stringify(jsonobj);
// typeof(exp) == "undefined"
// !exp && typeof(exp)!=”undefined” && exp!=0

#define _HOTFIX_FIXRESULT(result, msg, return_code) \
if (result == HotfixJsAdapterClassFixResultException || result == HotfixJsAdapterClassFixResultFail) { \
    Hotfix_LogJsException(msg, nil); \
    return_code; \
}


/// 单例缓存
static NSLock *_Hotfix_JsAdapter_OnceLock;
static NSMutableDictionary *_Hotfix_JsAdapter_OnceCache;

/// NSNull 静态对象
NSObject * Hotfix_Invocation_JsNull = nil;

// Fix
static NSString * const kHotfixJsAdapterFixMethodBefore = @"before";
static NSString * const kHotfixJsAdapterFixMethodInstead = @"instead";
static NSString * const kHotfixJsAdapterFixMethodAfter = @"after";

/// Hotfix 结果
/// @discussion: 失败：小于或等于 0；成功：大于0
typedef NS_ENUM(NSUInteger, HotfixJsAdapterClassFixResult) {
    /// 参数异常
    HotfixJsAdapterClassFixResultException  = 0,
    
    HotfixJsAdapterClassFixResultExisted    = 100,  ///< 已存在
    HotfixJsAdapterClassFixResultAddOrFixed = 200,  ///< 成功，添加或者fix
    HotfixJsAdapterClassFixResultReplace    = 201,  ///< 替换
    
    HotfixJsAdapterClassFixResultFail = HotfixJsAdapterClassFixResultException, ///< 失败
};

// 注册方法类型
typedef NS_ENUM(NSUInteger, HotfixJsAdapterDynamicPropertyMethodType) {
    HotfixJsAdapterDynamicPropertyMethodTypeGetter,
    HotfixJsAdapterDynamicPropertyMethodTypeSetter,
};

#ifndef weakify
    #if DEBUG
        #if __has_feature(objc_arc)
            #define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
        #else
            #define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
        #endif
    #else
        #if __has_feature(objc_arc)
            #define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
        #else
            #define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
        #endif
    #endif
#endif


#ifndef strongify
    #if DEBUG
        #if __has_feature(objc_arc)
            #define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
        #else
            #define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
        #endif
    #else
        #if __has_feature(objc_arc)
            #define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
        #else
            #define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
        #endif
    #endif
#endif


@interface HotfixJsAdapter ()
@property (nonatomic, strong) JSContext *jsContext;
@property (nonatomic, strong) NSRegularExpression *regex;

@property (nonatomic, strong) NSMutableArray<id<AspectToken>> *fixTokens;


@end

@implementation HotfixJsAdapter

- (void)dealloc {
    // dealloc时，自动清除之前的hook
    [self p_removeAllFixToken];
}

+ (void)load {
    Hotfix_Invocation_JsNull = NSObject.new;
    _Hotfix_JsAdapter_OnceLock = NSLock.new;
    _Hotfix_JsAdapter_OnceCache = NSMutableDictionary.new;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self p_registerManager];
    }
    return self;
}

- (void)p_registerManager {
    self.regex = [NSRegularExpression regularExpressionWithPattern:@"(?<!\\\\)\\.\\s*(\\w+)\\s*\\(" options:0 error:nil];
    self.fixTokens = NSMutableArray.new;
}

#pragma mark register
- (void)p_registerJSContext {
    @weakify(self);
    self.jsContext = [[JSContext alloc] init];
    self.jsContext.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        Hotfix_LogJsException(exception.toObject, nil);
    };
    
    self.jsContext[@"_hf_call_log"] = ^() {
        NSArray *args = [JSContext currentArguments];
        NSMutableString *log = NSMutableString.new;
        for (JSValue *jsVal in args) {
            [log appendFormat:@" %@;", jsVal];
        }
        NSLog(@"Javascript log:%@", log);
    };
    
    self.jsContext[@"_hf_call_catch"] = ^(JSValue *msg, JSValue *stack) {
        Hotfix_LogJsException(msg.toObject, stack.toObject);
    };
    
    self.jsContext[@"_hf_call_fixMethod"] = ^HotfixJsAdapterClassFixResult(NSString *className, NSString *selectorName, BOOL isClassMethod, NSString *fixType, JSValue *fixImpl) {
        @strongify(self);
        
        if (!className.length || !selectorName.length || !fixImpl) {
            Hotfix_LogJsException(@"方法名/类名/fix JS 不存在", nil);
            return HotfixJsAdapterClassFixResultException;
        }
        
        AspectOptions options = AspectPositionInstead;
        // 匹配hook类型
        if ([fixType isEqualToString:kHotfixJsAdapterFixMethodBefore]) {
            options = AspectPositionBefore;
        } else if ([fixType isEqualToString:kHotfixJsAdapterFixMethodInstead]) {
            options = AspectPositionInstead;
        } else if ([fixType isEqualToString:kHotfixJsAdapterFixMethodAfter]) {
            options = AspectPositionAfter;
        } else {
            Hotfix_LogJsException(@"替换类型错误", nil);
            return HotfixJsAdapterClassFixResultException;
        }
        
        return [self p_fixMethod:selectorName cls:className isClassMethod:isClassMethod options:options jsImpl:fixImpl];
    };
    
    self.jsContext[@"_hf_call_invocation"] = ^id(JSValue *instance, NSString *clsName, NSString *method, JSValue *arges, BOOL isSuper) {
        @strongify(self);
        if (!method.length) {
            Hotfix_LogJsException(@"方法名不存在", nil);
            return nil;
        }
        
        return [self p_callMethod:method instance:instance cls:clsName arges:arges isSuper:isSuper];
    };
    
    self.jsContext[@"_hf_call_callBlock"] = ^id(JSValue *block, JSValue *args) {
        NSInteger count = args.toArray.count;
        NSMutableArray *callArgs = NSMutableArray.new;
        
        for (NSInteger row = 0; row < count; row++) {
            JSValue *jsVal = args[row];
            if (!jsVal.isUndefined && !jsVal.isNull && [jsVal hasProperty:kHotfix_Invocation_Block_IsBlock]) {
                id block = Hotfix_Block_Decode(jsVal);
                [callArgs addObject:block ?: NSNull.null];
            } else {
                [callArgs addObject:jsVal];
            }
        }
        
        block = Hotfix_Block_HookJs(block) ?: block;
        return [block callWithArguments:callArgs];
    };
    
    self.jsContext[@"_hf_call_protocol"] = ^id(NSString *protocol) {
        return NSProtocolFromString(protocol);
    };
    
    self.jsContext[@"_hf_call_addCls"] = ^HotfixJsAdapterClassFixResult(NSString *clsName, NSString *superClsName) {
        @strongify(self);
        if (!clsName.length) {
            Hotfix_LogJsException(@"类名不存在", nil);
            return HotfixJsAdapterClassFixResultException;
        }
        return [self p_addCls:clsName superCls:superClsName];
    };
    
    self.jsContext[@"_hf_call_addMethod"] = ^HotfixJsAdapterClassFixResult(NSString *selectorName, NSString *clsName, BOOL isClassMethod, NSString *rtnType, NSArray<NSString *> *arges, JSValue *fixImpl) {
        @strongify(self);
        if (!clsName.length || !selectorName.length || !rtnType.length || !fixImpl) {
            Hotfix_LogJsException(@"类名/方法名/返回类型/js Impl 不存在", nil);
            return HotfixJsAdapterClassFixResultException;
        }
        
        HotfixJsAdapterClassFixResult result = [self p_addClsMethod:selectorName cls:clsName isClassMethod:isClassMethod rtnType:rtnType arges:arges];
        _HOTFIX_FIXRESULT(result, @"添加原始方法失败", return result;);
        result = [self p_fixMethod:selectorName cls:clsName isClassMethod:isClassMethod options:AspectPositionInstead jsImpl:fixImpl];
        return result;
    };
    
    self.jsContext[@"_hf_call_addProperty"] = ^HotfixJsAdapterClassFixResult(NSString *name, NSString *clsName, NSString *type, NSDictionary<NSString *, id> *att, JSValue *getterImpl, JSValue *setterImpl) {
        @strongify(self);
        HotfixJsAdapterDynamicProperty *property = [HotfixJsAdapterDynamicProperty propertyWithName:name cls:clsName type:type att:att];
        
        HotfixJsAdapterClassFixResult result = [self p_addProperty:property];
        _HOTFIX_FIXRESULT(result, @"创建属性失败", return result;);
        result = [self p_addPropertyMethod:property methodType:HotfixJsAdapterDynamicPropertyMethodTypeGetter jsMethod:getterImpl];
        _HOTFIX_FIXRESULT(result, @"创建getter方法失败", return result;);
        result = [self p_addPropertyMethod:property methodType:HotfixJsAdapterDynamicPropertyMethodTypeSetter jsMethod:setterImpl];
        _HOTFIX_FIXRESULT(result, @"创建setter方法失败", return result;);
        
        return result;
    };
    
    
#pragma mark Null
    self.jsContext[@"_hf_call_null"] = ^id() {
        return Hotfix_Invocation_JsNull;
    };
    
#pragma mark Struct & Thread & Defined
    [self p_registerJSContextStruct];
    [self p_registerJSContextThread];
    [self p_registerJSContextDefined];
    
}

- (void)p_registerJSContextStruct {
    @weakify(self);
    self.jsContext[@"_hf_call_rect"] = ^id(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
        @strongify(self);
        CGRect rect = CGRectMake(x, y, width, height);
        return [JSValue valueWithRect:rect inContext:self.jsContext];
    };
    
    self.jsContext[@"_hf_call_point"] = ^id(CGFloat x, CGFloat y) {
        @strongify(self);
        CGPoint point = CGPointMake(x, y);
        return [JSValue valueWithPoint:point inContext:self.jsContext];
    };
    
    self.jsContext[@"_hf_call_size"] = ^id(CGFloat width, CGFloat height) {
        @strongify(self);
        CGSize size = CGSizeMake(width, height);
        return [JSValue valueWithSize:size inContext:self.jsContext];
    };
    
    self.jsContext[@"_hf_call_range"] = ^id(NSUInteger loc, NSUInteger len) {
        @strongify(self);
        NSRange range = NSMakeRange(loc, len);
        return [JSValue valueWithRange:range inContext:self.jsContext];
    };
}

- (void)p_registerJSContextThread {
    self.jsContext[@"_hf_call_dispatch"] = ^(BOOL isMain, NSString *priority, BOOL async, CGFloat after, JSValue *block) {
        
        dispatch_queue_t queue = NULL;
        if (isMain) {
            queue = dispatch_get_main_queue();
        } else {
            if ([priority isEqualToString:@"high"]) {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
            } else if ([priority isEqualToString:@"low"]) {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            } else {
                queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            }
        }
        
        if (after > 0.1) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(after * NSEC_PER_SEC)), queue, ^{
                [block callWithArguments:@[]];
            });
        } else if (async) {
            dispatch_async(queue, ^{
                [block callWithArguments:@[]];
            });
        } else {
            dispatch_sync(queue, ^{
                [block callWithArguments:@[]];
            });
        }
    };
    
    self.jsContext[@"_hf_call_main"] = ^(JSValue *block) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [block callWithArguments:@[]];
        });
    };
    
    self.jsContext[@"_hf_call_global"] = ^(JSValue *block) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [block callWithArguments:@[]];
        });
    };
    
    self.jsContext[@"_hf_call_after"] = ^(JSValue *block, CGFloat time, BOOL isMain) {
        dispatch_queue_t queue;
        if (isMain) {
            queue = dispatch_get_main_queue();
        } else {
            queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), queue, ^{
            [block callWithArguments:@[]];
        });
    };
    
    // 单例
    self.jsContext[@"_hf_call_once"] = ^(NSString *onceKey, JSValue *block) {
        if (!onceKey.length) {
            return;
        }
        
        [_Hotfix_JsAdapter_OnceLock lock];
        HotfixJsAdapterOnceObject *object;
        if (_Hotfix_JsAdapter_OnceCache[onceKey]) {
            object = _Hotfix_JsAdapter_OnceCache[onceKey];
        } else {
            object = HotfixJsAdapterOnceObject.new;
            _Hotfix_JsAdapter_OnceCache[onceKey] = object;
        }
        [_Hotfix_JsAdapter_OnceLock unlock];
        
        dispatch_once_t *oncePredicate = &(object->_once);
        dispatch_once(oncePredicate, ^{
            [block callWithArguments:@[]];
        });
    };
}

- (void)p_registerJSContextDefined {
    // BASE DEFINED
    self.jsContext[@"_hf_call_floatMin"] = ^CGFloat() {
        return CGFLOAT_MIN;
    };
    
    self.jsContext[@"_hf_call_floatMax"] = ^CGFloat() {
        return CGFLOAT_MAX;
    };
    
    self.jsContext[@"_hf_call_intMin"] = ^NSInteger() {
        return NSIntegerMin;
    };
    
    self.jsContext[@"_hf_call_intMax"] = ^NSInteger() {
        return NSIntegerMax;
    };
    
}

#pragma mark - Run JS
- (void)runJS:(NSString *)js completion:(nullable void (^)(BOOL))completion {
    [self p_registerJSContext];
    [self p_removeAllFixToken];
    
    // 注册全局
    NSString *patch = [[NSBundle mainBundle] pathForResource:@"patchGlobal" ofType:@"js"];
    NSError *err;
    NSString *jsContent = [NSString stringWithContentsOfFile:patch encoding:NSUTF8StringEncoding error:&err];
    [self p_evaluateScript:jsContent regex:false]; // 注册全局
    
    [self p_evaluateScript:js regex:true];  // 执行hotfix
    
    if (completion) {
        completion(true);
    }
    
}

- (JSValue *)p_evaluateScript:(NSString *)script regex:(BOOL)isRegex {
    // 正则表达式，替换函数
    // 在方法前添加catch
    NSString *formatedScript = script;
    if (isRegex) {
        formatedScript = [self.regex stringByReplacingMatchesInString:script options:0 range:NSMakeRange(0, script.length) withTemplate:@"._hf_catch_realFun(\"$1\")("];
    }
    
    // 增加监控
    formatedScript = [NSString stringWithFormat:@";(function(){try{\n%@\n}catch(e){_hf_call_catch(e.message, e.stack)}})();", formatedScript];
    
    JSValue *jsVal = nil;
    @try {
        jsVal = [self.jsContext evaluateScript:formatedScript];
    } @catch (NSException *exception) {
        Hotfix_LogJsException(exception, exception.callStackSymbols);
    }
    
    return jsVal;
}

- (void)p_removeAllFixToken {
    for (id<AspectToken> token in self.fixTokens) {
        [token remove];
    }
}

#pragma mark - JS Observe Method
/// fix 方法
/// @param selectorName 方法名
/// @param clsName 类名
/// @param isClassMethod 是否为父类方法
/// @param option fix 类型
/// @param jsImpl 具体实现
- (HotfixJsAdapterClassFixResult)p_fixMethod:(NSString *)selectorName cls:(NSString *)clsName isClassMethod:(BOOL)isClassMethod options:(AspectOptions)option jsImpl:(JSValue *)jsImpl {
    
    SEL sel = NSSelectorFromString(selectorName);
    // 获取类
    Class cls = NSClassFromString(clsName);
    if (isClassMethod) {
        cls = object_getClass(cls);
    }
    
    if (!cls) {
        Hotfix_LogJsException(@"类不存在", nil);
        return HotfixJsAdapterClassFixResultException;
    }
    
    @try {
        NSError *err;
        id<AspectToken> token = [cls aspect_hookSelector:sel withOptions:option usingBlock:^(id<AspectInfo> aspectInfo) {
            
            NSInvocation *invocation = aspectInfo.originalInvocation;
            NSArray *arguments = aspectInfo.arguments;
            id instance = aspectInfo.instance;
            
            @weakify(self);
            // Call
            JSValue * (^invocationRun)(void) = ^JSValue *() {
                @strongify(self);
                [invocation invoke];
                JSValue *jsRtn = [invocation hf_getReturnValue:self.jsContext];
                return jsRtn;
            };
            JSValue * (^invocationSetArges)(void) = ^JSValue *() {
                @strongify(self);
                NSArray *arges = [JSContext currentArguments];
                NSMethodSignature *methodSignature = [invocation methodSignature];
                NSInteger numberOfArguments = [methodSignature numberOfArguments];
                if ((numberOfArguments - 2) == arges.count) {
                    JSValue *jsValArges = [JSValue valueWithObject:arges inContext:self.jsContext];
                    HOTFIX_INVOCATION_SET_ARGS(invocation, jsValArges, return nil)
                } else {
                    Hotfix_LogJsException(@"invocationSetArges 参数数量不匹配", nil);
                }
                
                return invocationRun();
            };
            JSValue * (^invocationSetArgeAtIndex)(JSValue *arge, NSUInteger index) = ^JSValue *(JSValue *arge, NSUInteger index) {
                HOTFIX_INVOCATION_SET_ARG(invocation, index, arge, return nil);
                return invocationRun();
            };
            NSDictionary *invocationHandle = @{
                @"run": [invocationRun copy],
                @"updateArgsAndRun": [invocationSetArges copy],
                @"updateArgAtIndexAndRun": [invocationSetArgeAtIndex copy],
            };
            
            JSValue *jsval = [jsImpl callWithArguments:@[instance, invocationHandle, arguments]];
            
            if (option != AspectPositionInstead || !jsval) {
                // 非替换函数，返回值为空，则直接返回
                return;
            }
            
            // 配置返回值
            HOTFIX_INVOCATION_SET_RTN(invocation, jsval)
            
        } error:&err];
        
        if (err) {
            Hotfix_LogJsException(err, nil);
            return HotfixJsAdapterClassFixResultException;
        }
        
        if (token) {
            [self.fixTokens addObject:token];
        } else {
            Hotfix_LogJsException(@"fix token 不存在，异常！", nil);
            return HotfixJsAdapterClassFixResultFail;
        }
        
    } @catch (NSException *exception) {
        Hotfix_LogJsException(exception, exception.callStackSymbols);
        return HotfixJsAdapterClassFixResultException;
    }
    
    return HotfixJsAdapterClassFixResultAddOrFixed;
}

/// 动态添加类
/// @param clsName 类名
/// @param superClsName 父类名
- (HotfixJsAdapterClassFixResult)p_addCls:(NSString *)clsName superCls:(NSString *)superClsName {
    Class cls = NSClassFromString(clsName);
    if (cls) {
        // 类已经存在
        return HotfixJsAdapterClassFixResultExisted;
    }
    
    Class superCls = NSClassFromString(superClsName);
    if (!superCls) {
        Hotfix_LogJsException(@"父类不存在", nil);
        return HotfixJsAdapterClassFixResultException;
    }
    
    cls = objc_allocateClassPair(superCls, clsName.UTF8String, 0);
    if (!cls) {
        Hotfix_LogJsException(@"动态生成类不成功", nil);
        return HotfixJsAdapterClassFixResultFail;
    }
    
    // 注册runtime
    objc_registerClassPair(cls);
    
    return HotfixJsAdapterClassFixResultAddOrFixed;
}

/// 添加方法
/// @param selectorName 方法名
/// @param clsName 类名
/// @param isClassMethod 是否为父类
/// @param rtnType 返回类型
/// @param arges 入参类型
/// @discussion 只添加方法，适配方法签名，不包含实现
- (HotfixJsAdapterClassFixResult)p_addClsMethod:(NSString *)selectorName cls:(NSString *)clsName isClassMethod:(BOOL)isClassMethod rtnType:(NSString *)rtnType arges:(NSArray<NSString *> *)arges {
    return [self p_addClsMethod:selectorName cls:clsName isClassMethod:isClassMethod rtnType:rtnType arges:arges inheritImpl:(IMP)_hotfix_hookEmptySelectorImpl];
}

/// 添加方法
/// @param selectorName 方法名
/// @param clsName 类名
/// @param isClassMethod 是否为父类
/// @param rtnType 返回类型
/// @param arges 入参类型
/// @param inheritImpl 原方法指针
/// @discussion 只添加方法，适配方法签名，不包含实现
- (HotfixJsAdapterClassFixResult)p_addClsMethod:(NSString *)selectorName cls:(NSString *)clsName isClassMethod:(BOOL)isClassMethod rtnType:(NSString *)rtnType arges:(NSArray<NSString *> *)arges inheritImpl:(IMP)inheritImpl {
    
    Class cls = NSClassFromString(clsName);
    if (!cls) {
        Hotfix_LogJsException(@"类不存在", nil);
        return HotfixJsAdapterClassFixResultException;
    }
    
    // 校验方式是否已经存在
    SEL sel = NSSelectorFromString(selectorName);
    Method method = isClassMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (method) {
        return HotfixJsAdapterClassFixResultExisted;
    }
    
    // 获取类
    if (isClassMethod) {
        cls = object_getClass(cls);
    }
    
    // 静态成员类型
    NSDictionary<NSString *, NSArray *> *typeSignatureDict = Hotfix_Block_TypeSignatureDict();
    
    NSString *funcSignature = @"@0";
    NSInteger size = MAX(8, sizeof(void *));
    
    // 嵌入 SEL
    NSString *type = typeSignatureDict[@"SEL"].firstObject;
    funcSignature = [funcSignature stringByAppendingString:[NSString stringWithFormat:@"%@%@", type, [@(size) stringValue]]];
    size += MAX(8, [typeSignatureDict[@"SEL"][1] integerValue]);
    
    // 设置入参
    for (NSInteger i = 0; i < arges.count; i++) {
        NSString *typeName = [arges[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSString *type = typeSignatureDict[typeName].firstObject;
        if (!type.length) {
            Hotfix_LogJsException(@"SEL 入参类型错误", nil);
            type = typeSignatureDict[@"id"].firstObject;
        }
        
        funcSignature = [funcSignature stringByAppendingString:[NSString stringWithFormat:@"%@%@", type, [@(size) stringValue]]];
        size += MAX(8, [(typeSignatureDict[typeName] ?: typeSignatureDict[@"id"])[1] integerValue]);
    }
    
    // 设置反参
    NSString *rtnTypeName = typeSignatureDict[rtnType].firstObject;
    if (!rtnTypeName.length) {
        Hotfix_LogJsException(@"SEL 返回参类型错误", nil);
        rtnTypeName = typeSignatureDict[@"void"].firstObject;
    }
    funcSignature  =[[NSString stringWithFormat:@"%@%@", rtnTypeName, [@(size) stringValue]] stringByAppendingString:funcSignature];
    
    // 获取 IMP 指针
    IMP hookImpl = inheritImpl;
    if (!hookImpl) {
        Hotfix_LogJsException(@"impl指针不存在", nil);
        hookImpl = _hotfix_hookEmptySelectorImpl;
    }
    
    // 添加方法
    BOOL success = class_addMethod(cls, sel, hookImpl, funcSignature.UTF8String);
    if (success) {
        // 添加完成后，再替换实现
        return HotfixJsAdapterClassFixResultAddOrFixed;
    } else {
        Hotfix_LogJsException(@"生成 SEL 失败", nil);
        return HotfixJsAdapterClassFixResultFail;
    }
}


/// 添加属性
/// @param property 属性
/// @discussion 只添加 ivar 属性，不操作 getter & setter 实现
- (HotfixJsAdapterClassFixResult)p_addProperty:(HotfixJsAdapterDynamicProperty *)property {
    
    Class cls = NSClassFromString(property.cls);
    if (!cls) {
        Hotfix_LogJsException(@"类不存在", nil);
        return HotfixJsAdapterClassFixResultException;
    }
    
    Ivar ivar = class_getInstanceVariable(cls, [[NSString stringWithFormat:@"_%@", property.name] UTF8String]);
    if (ivar) {
        return HotfixJsAdapterClassFixResultExisted;
    }
    
    // 静态成员类型
    NSDictionary<NSString *, NSArray *> *typeSignatureDict = Hotfix_Block_TypeSignatureDict();
    NSString *typeEncoding = typeSignatureDict[property.type].firstObject;
    if (!typeEncoding) {
        Hotfix_LogJsException(@"类型错误", nil);
        return HotfixJsAdapterClassFixResultException;
    }
    
    // 肯定有2个类型
    NSInteger attributeCount = 2;

    if (property.nonatomic) ++attributeCount;
    if (property.readonly) ++attributeCount;
    if (property.getter) ++attributeCount;
    if (property.setter) ++attributeCount;
    if (property.isObj) ++attributeCount;

    // Build the attributes
    objc_property_attribute_t *attrs = (objc_property_attribute_t *)malloc(sizeof(objc_property_attribute_t) * attributeCount);
    NSInteger i = 0;
    
    // Type encoding (must be first)
    objc_property_attribute_t type = { "T", typeEncoding.UTF8String };
    attrs[i] = type;
    i++;
    
    if (property.readonly) {
        objc_property_attribute_t readonly = { "R", "" };
        attrs[i] = readonly;
        i++;
    }
    
    if (property.isObj) {
        switch (property.role) {
            case HotfixJsAdapterDynamicPropertyRoleCopy: {
                // copy
                objc_property_attribute_t ownership = { "C", "" };
                attrs[i] = ownership;
            }
                break;
                
            case HotfixJsAdapterDynamicPropertyRoleWeak: {
                // weak
                objc_property_attribute_t ownership = { "W", "" };
                attrs[i] = ownership;
            }
                break;
                
            case HotfixJsAdapterDynamicPropertyRoleDefault:
            default: {
                // strong
                objc_property_attribute_t ownership = { "&", "" };
                attrs[i] = ownership;
            }
                break;
        }
        
        i++;
    }
    
    if (property.nonatomic) {
        objc_property_attribute_t nonatomic = { "N", "" };
        attrs[i] = nonatomic;
        i++;
    }
    
    // Getter
    if (property.getter) {
        objc_property_attribute_t getter = { "G", property.getter.UTF8String };
        attrs[i] = getter;
        i++;
    }

    // Setter
    if (property.setter) {
        objc_property_attribute_t setter = { "S", property.setter.UTF8String };
        attrs[i] = setter;
        i++;
    }

    // Backing ivar (must be last)
    NSString *variableName = [NSString stringWithFormat:@"_%@", property.name];
    objc_property_attribute_t backingivar = { "V", variableName.UTF8String };
    attrs[i] = backingivar;
    
    BOOL success = class_addProperty(cls, property.name.UTF8String, (const objc_property_attribute_t *)attrs, attributeCount);
    
    // 释放
    free((void *)attrs);
    
    return success ? HotfixJsAdapterClassFixResultAddOrFixed : HotfixJsAdapterClassFixResultFail;

}


/// 添加属性 getter/setter
/// @param property 属性
/// @param methodType 方法类型
/// @param jsMethod js实现，可为空
- (HotfixJsAdapterClassFixResult)p_addPropertyMethod:(HotfixJsAdapterDynamicProperty *)property methodType:(HotfixJsAdapterDynamicPropertyMethodType)methodType jsMethod:(nullable JSValue *)jsMethod {
    
    Class cls = NSClassFromString(property.cls);
    if (!cls) {
        Hotfix_LogJsException(@"类不存在", nil);
        return HotfixJsAdapterClassFixResultException;
    }
    
    SEL sel = NULL;
    NSString *selName = nil;
    NSString *rtnType = nil;
    NSArray<NSString *> *arges = nil;
    
    if (methodType == HotfixJsAdapterDynamicPropertyMethodTypeGetter) {
        selName = property.name;
        sel = NSSelectorFromString(selName);
        rtnType = property.type;
        arges = @[];
    } else if (methodType == HotfixJsAdapterDynamicPropertyMethodTypeSetter) {
        selName = [NSString stringWithFormat:@"set%@%@:", [property.name substringToIndex:1].uppercaseString, [property.name substringFromIndex:1]];
        sel = NSSelectorFromString(selName);
        rtnType = @"void";
        arges = @[property.type];
    }
    
    if (!sel) {
        Hotfix_LogJsException(@"方法类型出错或sel生成出错", nil);
        return HotfixJsAdapterClassFixResultException;
    }
    
    Method method = class_getInstanceMethod(cls, sel);
    HotfixJsAdapterClassFixResult result = HotfixJsAdapterClassFixResultAddOrFixed;
    if (!method) {
        // 原有方法，不存在，先添加方法
        
#define _HOTFIX_PROPERTY_SWITCH_CASE(_method, _type, _type_name) \
} else if ([property.type isEqualToString:@_type]) { impl = (IMP)_Hotfix_Property_##_method##_##_type_name;
        
#define _HOTFIX_PROPERTY_SWITCH(_method) \
if (false) { \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "id", id) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "BOOL", BOOL) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "bool", BOOL) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "int", int) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "char", char) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "short", short) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "unsigned short", unsignedshort) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "unsigned int", unsignedint) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "long", long) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "unsigned long", unsignedlong) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "long long", longlong) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "unsigned long long", unsignedlonglong) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "float", float) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "double", double) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "CGFloat", CGFloat) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "NSInteger", NSInteger) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "NSUInteger", NSUInteger) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "SEL", SEL) \
\
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "Class", Class) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "CGRect", CGRect) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "CGPoint", CGPoint) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "CGSize", CGSize) \
_HOTFIX_PROPERTY_SWITCH_CASE(_method, "NSRange", NSRange) \
} else { \
Hotfix_LogJsException(@"方法属性出错", nil); \
return HotfixJsAdapterClassFixResultException; \
}
        
        IMP impl = NULL;
        if (methodType == HotfixJsAdapterDynamicPropertyMethodTypeGetter) {
            _HOTFIX_PROPERTY_SWITCH(Getter)
        } else if (methodType == HotfixJsAdapterDynamicPropertyMethodTypeSetter) {
            _HOTFIX_PROPERTY_SWITCH(Setter)
        }
        
        result = [self p_addClsMethod:selName cls:property.cls isClassMethod:property.isClass rtnType:rtnType arges:arges inheritImpl:impl];
        _HOTFIX_FIXRESULT(result, @"添加属性方法失败", return result;);
        
    }
    
    if (jsMethod && !jsMethod.isNull && !jsMethod.isUndefined) {
        // 替换方法
        result = [self p_fixMethod:selName cls:property.cls isClassMethod:property.isClass options:AspectPositionInstead jsImpl:jsMethod];
        _HOTFIX_FIXRESULT(result, @"替换属性方法失败", return result;);
    }

    return result;
}


#pragma mark Call Method
/// 调用方法
/// @param selectorName 方法名
/// @param instance 实例
/// @param clsName 类名
/// @param arges 入参
/// @param isSuper 是否为父类调用
- (id)p_callMethod:(NSString *)selectorName instance:(JSValue *)instance cls:(NSString *)clsName arges:(JSValue *)arges isSuper:(BOOL)isSuper {
    // 执行实例
    id target = instance.toObject;
    // 是否实例方法
    BOOL isInstance = true;
    if (!instance || instance.isNull || instance.isUndefined) {
        if (clsName.length) {
            target = NSClassFromString(clsName);
            if (!target) {
                Hotfix_LogJsException([NSString stringWithFormat:@"callMethod类不存在: %@, %@, %@, %@", instance.toObject, selectorName, clsName, arges.toObject], nil);
                return nil;
            } else {
                isInstance = false;
            }
        } else {
            Hotfix_LogJsException([NSString stringWithFormat:@"callMethod空调用: %@, %@, %@, %@", instance.toObject, selectorName, clsName, arges.toObject], nil);
            // 空调用
            return nil;
        }
    } else if (class_isMetaClass(object_getClass(target))) {
        isInstance = false;
    }

    SEL selector = NSSelectorFromString(selectorName);
    
    if (isSuper && isInstance) {
        Class superCls = [[target class] superclass];
        Method superMethod = class_getInstanceMethod(superCls, selector);
        IMP superIMP = method_getImplementation(superMethod);
        
        if (superIMP != _objc_msgForward) {
            NSString *superSelectorName = [NSString stringWithFormat:@"_HOTFIX_SUPER_%@", selectorName];
            SEL superSelector = NSSelectorFromString(superSelectorName);

            class_addMethod([target class], superSelector, superIMP, method_getTypeEncoding(superMethod));
            selector = superSelector;
            
        } else {
            // 父类已经被hook，此时需要替换imp指针，未完成
//            selector = NSSelectorFromString([@"aspects_" stringByAppendingFormat:@"_%@", NSStringFromSelector(selector)]);
        }
    }
    
    NSMethodSignature *methodSignature = nil;
    if (isInstance) {
        Class targetClass = [target class];
        methodSignature = [targetClass instanceMethodSignatureForSelector:selector];
    } else {
        methodSignature = [target methodSignatureForSelector:selector];
    }
    
    if (!methodSignature) {
        Hotfix_LogJsException([NSString stringWithFormat:@"callMethod方法不存在: %@, %@, %@, %@", instance.toObject, selectorName, clsName, arges.toObject], nil);
        return nil;
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    [invocation setTarget:target];
    [invocation setSelector:selector];
    HOTFIX_INVOCATION_SET_ARGS(invocation, arges, return nil)
    
    [invocation invoke];
    
    JSValue *jsRtnVal = [invocation hf_getReturnValue:self.jsContext];
    return jsRtnVal;
}

@end

