//
//  HotfixInvocationSetDefined.h
//  Hotfix
//
//  Created by nate on 2021/1/19.
//

#ifndef HotfixInvocationSetDefined_h
#define HotfixInvocationSetDefined_h


#import "HotfixLogDefined.h"
#import "HotfixInvocationMacro.h"

#import "HotfixBlockExtension.h"
#import "HotfixPointerContainer.h"

/**
 The reason of using defined instead of retainArguments below
 
 For efficiency, newly created NSInvocation objects don’t retain or copy their arguments, nor do they retain their targets, copy C strings, or copy any associated blocks. You should instruct an NSInvocation object to retain its arguments if you intend to cache it, because the arguments may otherwise be released before the invocation is invoked. NSTimer objects always instruct their invocations to retain their arguments, for example, because there’s usually a delay before a timer fires.
 
 Avoid using argumentsRetained because of which below
 Before this method is invoked, argumentsRetained returns NO; after, it returns YES.
 
 https://developer.apple.com/documentation/foundation/nsinvocation/1437838-retainarguments?language=objc
 
 */

#pragma mark - INVOCATION SET ARG & RTN

static NSString * const _kHotfix_Invocation_ClassKey = @"_hf_v_clsName";

/// 设置基础类型
#define _HOTFIX_INVOCATION_SET_CASE(_typeString, _type, _selector, _setValue_define) \
case _typeString: { \
    _type value = [_privateInvSet_jsVal.toObject _selector]; \
    _setValue_define \
    break; \
}

/// 设置方法SEL类型
#define _HOTFIX_INVOCATION_SET_SEL(_setValue_define) \
case ':': { \
    SEL value = NULL; \
    if (!_privateInvSet_jsVal.isNull && !_privateInvSet_jsVal.isUndefined) { \
        NSString *selName = [NSString stringWithFormat:@"%@", _privateInvSet_jsVal.toObject]; \
        value = NSSelectorFromString(selName); \
    } \
    _setValue_define \
    break; \
}

/// 设置结构体类型明细
#define _HOTFIX_INVOCATION_SET_STRUCT_CASE(_type, _methodName, _defaultValue, _setValue_define) \
if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
    _type value = _defaultValue; \
    if (!_privateInvSet_jsVal.isNull && !_privateInvSet_jsVal.isUndefined) { \
        value = [_privateInvSet_jsVal _methodName]; \
    } \
    _setValue_define \
    break; \
}

/// 设置结构体类型
#define _HOTFIX_INVOCATION_SET_STRUCT(_setValue_define) \
case '{': { \
    NSString *typeString = Hotfix_Invocation_StructName([NSString stringWithUTF8String:_privateInvSet_argumentType]); \
    \
    _HOTFIX_INVOCATION_SET_STRUCT_CASE(CGRect, toRect, CGRectZero, _setValue_define) \
    _HOTFIX_INVOCATION_SET_STRUCT_CASE(CGPoint, toPoint, CGPointZero, _setValue_define) \
    _HOTFIX_INVOCATION_SET_STRUCT_CASE(CGSize, toSize, CGSizeZero, _setValue_define) \
    _HOTFIX_INVOCATION_SET_STRUCT_CASE(NSRange, toRange, NSMakeRange(NSNotFound, 0), _setValue_define) \
    break; \
}

#define _HOTFIX_INVOCATION_SET_POINT(_setValue_define) \
case '^': \
case '*': { \
    void *value; \
    if ([_privateInvSet_jsVal.toObject isKindOfClass:HotfixPointerContainer.class]) { \
        HotfixPointerContainer *pointerContainer = _privateInvSet_jsVal.toObject; \
        value = pointerContainer->_pointer; \
    } \
    \
    _setValue_define \
    break; \
}

/// 设置类类型
#define _HOTFIX_INVOCATION_SET_CLASS(_setValue_define) \
case '#': { \
    Class value = nil; \
    if (_privateInvSet_jsVal.isNull || _privateInvSet_jsVal.isUndefined) { \
        \
    } else if ([_privateInvSet_jsVal hasProperty:_kHotfix_Invocation_ClassKey]) { \
        NSString *clsName = [NSString stringWithFormat:@"%@",  _privateInvSet_jsVal[_kHotfix_Invocation_ClassKey].toObject]; \
        value = NSClassFromString(clsName); \
    } else if (_privateInvSet_jsVal.isString) { \
        value = NSClassFromString(_privateInvSet_jsVal.toString); \
    } else if (class_isMetaClass(object_getClass(_privateInvSet_jsVal.toObject))) { \
        value = _privateInvSet_jsVal.toObject; \
    } \
    _setValue_define \
    break; \
}

/// 设置对象类型
#define _HOTFIX_INVOCATION_SET_INSTANCE(_setValue_define) \
case '@': { \
    __autoreleasing id value = nil; \
    if (_privateInvSet_jsVal.isNull || _privateInvSet_jsVal.isUndefined || ([_privateInvSet_jsVal.toObject  isKindOfClass:NSNumber.class] && strcmp([_privateInvSet_jsVal.toObject objCType], "c") == 0 && ![_privateInvSet_jsVal.toObject boolValue])) { \
    \
    } else if ([_privateInvSet_jsVal hasProperty:kHotfix_Invocation_Block_IsBlock]) { \
        value = Hotfix_Block_Decode(_privateInvSet_jsVal); \
    } else if (_privateInvSet_jsVal.toObject == Hotfix_Invocation_JsNull) { \
        value = NSNull.null; \
    } else { \
        value = _privateInvSet_jsVal.toObject; \
    } \
    _setValue_define \
    break; \
}

/// 设置INV参数核心代码
#define _HOTFIX_INVOCATION_SET_CORE_CODE(invocation, jsVal, _type_define, _setValue_define) \
NSInvocation *_privateInvSet_invocation = invocation; \
JSValue *_privateInvSet_jsVal = jsVal; \
\
NSMethodSignature *_privateInvSet_methodSignature = _privateInvSet_invocation.methodSignature; \
\
_type_define \
\
switch (_privateInvSet_argumentType[0] == 'r' ? _privateInvSet_argumentType[1] : _privateInvSet_argumentType[0]) { \
    _HOTFIX_INVOCATION_SET_CASE('c', char, charValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('C', unsigned char, unsignedCharValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('s', short, shortValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('S', unsigned short, unsignedShortValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('i', int, intValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('I', unsigned int, unsignedIntValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('l', long, longValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('L', unsigned long, unsignedLongValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('q', long long, longLongValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('Q', unsigned long long, unsignedLongLongValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('f', float, floatValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('d', double, doubleValue, _setValue_define) \
    _HOTFIX_INVOCATION_SET_CASE('B', BOOL, boolValue, _setValue_define) \
    \
    _HOTFIX_INVOCATION_SET_SEL(_setValue_define) \
    _HOTFIX_INVOCATION_SET_STRUCT(_setValue_define) \
    _HOTFIX_INVOCATION_SET_CLASS(_setValue_define) \
    _HOTFIX_INVOCATION_SET_INSTANCE(_setValue_define) \
    _HOTFIX_INVOCATION_SET_POINT(_setValue_define) \
    \
}

/// 设置INV参数
#define _HOTFIX_INVOCATION_SET_RTN_CODE    [_privateInvSet_invocation setReturnValue:&value];
#define _HOTFIX_INVOCATION_SET_ARG_CODE    [_privateInvSet_invocation setArgument:&value atIndex:_privateInvSet_index];

/// 获取返回参数类型
#define _HOTFIX_INVOCATION_SET_RTN_TYPE_CODE \
char _privateInvSet_argumentType[255]; \
strcpy(_privateInvSet_argumentType, [_privateInvSet_methodSignature methodReturnType]); \
if (strcmp(_privateInvSet_argumentType, @encode(Hotfix_Invocation_DoubleType)) == 0) { \
    strcpy(_privateInvSet_argumentType, @encode(double)); \
} \
if (strcmp(_privateInvSet_argumentType, @encode(Hotfix_Invocation_FloatType)) == 0) { \
    strcpy(_privateInvSet_argumentType, @encode(float)); \
}

/// 获取入参类型
#define _HOTFIX_INVOCATION_SET_ARG_TYPE_CODE(index, _failRtn_code) \
NSInteger _privateInvSet_index = index + 2; \
if (_privateInvSet_index > _privateInvSet_methodSignature.numberOfArguments - 1) { \
    Hotfix_LogJsException(@"参数数量错误", nil); \
    _failRtn_code; \
} \
const char *_privateInvSet_argumentType = [_privateInvSet_methodSignature getArgumentTypeAtIndex:_privateInvSet_index];


#pragma mark PUBLIC
// 设置INV返回参数
#define HOTFIX_INVOCATION_SET_RTN(invocation, jsVal) _HOTFIX_INVOCATION_SET_CORE_CODE(invocation, jsVal, _HOTFIX_INVOCATION_SET_RTN_TYPE_CODE, _HOTFIX_INVOCATION_SET_RTN_CODE)

// 设置INV入参
#define HOTFIX_INVOCATION_SET_ARG(invocation, index, jsVal, _failRtn_code) _HOTFIX_INVOCATION_SET_CORE_CODE(invocation, jsVal, _HOTFIX_INVOCATION_SET_ARG_TYPE_CODE(index, _failRtn_code), _HOTFIX_INVOCATION_SET_ARG_CODE)

// 设置INV入参
#define HOTFIX_INVOCATION_SET_ARGS(invocation, jsVal, _failRtn_code) \
NSMethodSignature *_privateInvSet_methodSignature = invocation.methodSignature; \
NSUInteger _privateInvSet_numberOfArguments = _privateInvSet_methodSignature.numberOfArguments; \
for (NSUInteger i = 0; i < _privateInvSet_numberOfArguments - 2; i++) { \
    JSValue *valObj = jsVal[i]; \
    HOTFIX_INVOCATION_SET_ARG(invocation, i, valObj, _failRtn_code) \
}


#endif /* HotfixInvocationSetDefined_h */
