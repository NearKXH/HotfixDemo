//
//  HotfixBlockExtension.m
//  Hotfix
//
//  Created by nate on 2021/1/19.
//

#import "HotfixBlockExtension.h"

#import <JavaScriptCore/JavaScriptCore.h>
#import <objc/message.h>

#import "HotfixInvocationSetDefined.h"
#import "NSInvocation+Hotfix.h"

/// Block 动态绑定key
static const void * const _kHotfix_Block_AssociatedKey = &_kHotfix_Block_AssociatedKey;

static NSString * const _kHotfix_Block_Callback = @"_hf_v_callback";

static NSString * const _kHotfix_Block_Arges = @"_hf_v_args";
static NSString * const _kHotfix_Block_RtnType = @"_hf_v_rtnType";

/// 注册方法签名
NSDictionary<NSString *, NSArray *> * Hotfix_Block_TypeSignatureDict() {
    static NSMutableDictionary<NSString *, NSArray *> *typeSignatureDict;
    if (!typeSignatureDict) {
        typeSignatureDict  = [NSMutableDictionary new];
        #define _HOTFIX_BLOCK_TYPE_SIGNATURE(_type) \
        [typeSignatureDict setObject:@[[NSString stringWithUTF8String:@encode(_type)], @(sizeof(_type))] forKey:@#_type];\

        _HOTFIX_BLOCK_TYPE_SIGNATURE(id);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(BOOL);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(int);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(void);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(char);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(short);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(unsigned short);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(unsigned int);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(long);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(unsigned long);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(long long);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(unsigned long long);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(float);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(double);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(bool);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(size_t);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(CGFloat);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(CGSize);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(CGRect);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(CGPoint);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(CGVector);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(NSRange);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(NSInteger);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(NSUInteger);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(Class);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(SEL);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(void*);
        _HOTFIX_BLOCK_TYPE_SIGNATURE(void *);
    }
    return typeSignatureDict;
}

/// 方法签名
static NSMethodSignature *_Hotfix_Block_MethodSignatureForSelector(id block, SEL _cmd, SEL aSelector) {
    uint8_t *p = (uint8_t *)((__bridge void *)block);
    p += sizeof(void *) * 2 + sizeof(int32_t) *2 + sizeof(uintptr_t) * 2;
    const char **signature = (const char **)p;
    return [NSMethodSignature signatureWithObjCTypes:*signature];
}

/// Block 方法转发
/// @param assignSlf block
/// @param selector selector
/// @param invocation invocation
static void _Hotfix_Block_ForwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation) {
    __strong id slf = assignSlf;
    BOOL isBlock = [[slf class] isSubclassOfClass:NSClassFromString(@"NSBlock")];
    if (!isBlock) {
        Hotfix_LogJsException(@"不是 Block 类型，设置出错", nil);
        return;
    }
    
    JSValue *jsFunc = Hotfix_Block_HookJs(slf);
    if (!jsFunc) {
        Hotfix_LogJsException(@"js block hook 失败", nil);
        return;
    }
    
    NSArray *argeList = [invocation hf_getArguments:jsFunc.context];
    JSValue *jsVal = [jsFunc callWithArguments:argeList];

    // 设置返回
    HOTFIX_INVOCATION_SET_RTN(invocation, jsVal);
}

JSValue * _Nullable Hotfix_Block_HookJs(id block) {
    // 获取动态绑定的jsVal
    JSValue *jsBlockObject = objc_getAssociatedObject(block, _kHotfix_Block_AssociatedKey);
    if (!jsBlockObject) {
        return nil;
    }
    
    if (![jsBlockObject isKindOfClass:JSValue.class]) {
        Hotfix_LogJsException(@"动态绑定 JsVal 类型错误", nil);
        return nil;
    }
    
    // 获取实际执行函数
    JSValue *jsFunc = jsBlockObject[_kHotfix_Block_Callback];
    if (!jsFunc || ![jsFunc isKindOfClass:JSValue.class]) {
        Hotfix_LogJsException(@"动态绑定 JsVal 获取 callback 失败", nil);
        return nil;
    }
    
    return jsFunc;
}

id Hotfix_Block_Decode(JSValue *jsVal) {
    NSObject *obj = NSObject.new;
    void (^block)(void) = [^(void){
        NSLog(@"%@", obj);
    } copy];

    uint8_t *p = (uint8_t *)((__bridge void *)block);
    p += sizeof(void *) + sizeof(int32_t) *2;
    void(**invoke)(void) = (void (**)(void))p;

    p += sizeof(void *) + sizeof(uintptr_t) * 2;
    const char **signature = (const char **)p;

    NSDictionary<NSString *, NSArray *> *typeSignatureDict = Hotfix_Block_TypeSignatureDict();

    NSString *funcSignature = @"@?0";

    // 设置入参
    NSArray *argesType = [jsVal[_kHotfix_Block_Arges] toArray];
    NSInteger size = sizeof(void *);
    for (NSInteger i = 0; i < argesType.count; i++) {
        NSString *typeName = [argesType[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        NSString *type = typeSignatureDict[typeName].firstObject;
        if (type.length == 0) {
            Hotfix_LogJsException(@"block 入参类型错误", nil);
            type = typeSignatureDict[@"id"].firstObject;
        }

        funcSignature = [funcSignature stringByAppendingString:[NSString stringWithFormat:@"%@%@", type, [@(size) stringValue]]];
        size += [(typeSignatureDict[typeName] ?: typeSignatureDict[@"id"])[1] integerValue];
    }

    // 设置反参
    NSString *rtnTypeName = [NSString stringWithFormat:@"%@", jsVal[_kHotfix_Block_RtnType]];
    NSString *rtnType = typeSignatureDict[rtnTypeName].firstObject;
    if (rtnType.length == 0) {
        Hotfix_LogJsException(@"block 返回参类型错误", nil);
        rtnType = typeSignatureDict[@"void"].firstObject;
    }
    funcSignature  =[[NSString stringWithFormat:@"%@%@",rtnType, [@(size) stringValue]] stringByAppendingString:funcSignature];

    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if ([funcSignature UTF8String][0] == '{') {
        //In some cases that returns struct, we should use the '_stret' API:
        //http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html
        //NSMethodSignature knows the detail but has no API to return, we can only get the info from debugDescription.
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:[funcSignature UTF8String]];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    *invoke = (void *)msgForwardIMP;

    const char *fs = [funcSignature UTF8String];
    char *s = malloc(strlen(fs));
    strcpy(s, fs);
    *signature = s;

    objc_setAssociatedObject(block, _kHotfix_Block_AssociatedKey, jsVal, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"NSBlock");
        #define _HOOK_METHOD(selector, func) \
        { \
            Method method = class_getInstanceMethod([NSObject class], selector); \
            BOOL success = class_addMethod(cls, selector, (IMP)func, method_getTypeEncoding(method)); \
            if (!success) { \
                class_replaceMethod(cls, selector, (IMP)func, method_getTypeEncoding(method)); \
            } \
        }

        _HOOK_METHOD(@selector(methodSignatureForSelector:), _Hotfix_Block_MethodSignatureForSelector);
        _HOOK_METHOD(@selector(forwardInvocation:), _Hotfix_Block_ForwardInvocation);
    });

    return block;
}


