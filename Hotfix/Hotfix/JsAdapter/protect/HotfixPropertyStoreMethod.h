//
//  HotfixPropertyStoreMethod.h
//  Hotfix
//
//  Created by nate on 2021/2/9.
//

#ifndef HotfixPropertyStoreMethod_h
#define HotfixPropertyStoreMethod_h

#pragma mark - Setter & Getter Method

static const void * const _Hotfix_Property_DefaultAssociatedKey = &_Hotfix_Property_DefaultAssociatedKey;
static const void * const _Hotfix_Property_WeakAssociatedKey = &_Hotfix_Property_WeakAssociatedKey;

#define _HOTFIX_PROPERTY_METHOD(_typeString, _typeName, _setter_code, _getter_code, _default_return) \
static void _Hotfix_Property_Setter_##_typeName(id slf, SEL _cmd, _typeString newValue) { \
    NSString *selectorName = NSStringFromSelector(_cmd); \
    if (selectorName.length < 6 || ![selectorName hasPrefix:@"set"] || ![selectorName hasSuffix:@":"]) { \
        Hotfix_LogJsException([NSString stringWithFormat:@"setter 方法名错误: %@, class: %@", selectorName, slf], nil); \
        return; \
    } \
    \
    NSString *propertyName = [NSString stringWithFormat:@"%@%@", [[selectorName substringWithRange:NSMakeRange(3, 1)] lowercaseString], [selectorName substringWithRange:NSMakeRange(4, selectorName.length - 5)] ?: @""]; \
    objc_property_t ivar = class_getProperty([slf class], propertyName.UTF8String); \
    if (!ivar) { \
        Hotfix_LogJsException([NSString stringWithFormat:@"属性参数不存在: %@, class: %@", propertyName, slf], nil); \
        return; \
    } \
    \
    _setter_code \
    \
    char * weak = property_copyAttributeValue(ivar, "W"); \
    BOOL isWeak = weak != NULL; \
    if (isWeak) { \
        NSMapTable *weakAssociated = objc_getAssociatedObject(slf, _Hotfix_Property_WeakAssociatedKey); \
        if (!weakAssociated) { \
            weakAssociated = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableWeakMemory]; \
            objc_setAssociatedObject(slf, _Hotfix_Property_WeakAssociatedKey, weakAssociated, OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
        } \
        [weakAssociated setObject:value forKey:propertyName]; \
    } else { \
        NSMutableDictionary *defaultAssociated = objc_getAssociatedObject(slf, _Hotfix_Property_DefaultAssociatedKey); \
        if (!defaultAssociated) { \
            defaultAssociated = NSMutableDictionary.new; \
            objc_setAssociatedObject(slf, _Hotfix_Property_DefaultAssociatedKey, defaultAssociated, OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
        } \
        defaultAssociated[propertyName] = value; \
    } \
} \
\
static _typeString _Hotfix_Property_Getter_##_typeName(id slf, SEL _cmd) { \
    NSString *propertyName = [NSString stringWithFormat:@"%@", NSStringFromSelector(_cmd)]; \
    objc_property_t ivar = class_getProperty([slf class], propertyName.UTF8String); \
    if (!ivar) { \
        Hotfix_LogJsException([NSString stringWithFormat:@"属性参数不存在: %@, class: %@", propertyName, slf], nil); \
        return _default_return; \
    } \
    \
    char * weak = property_copyAttributeValue(ivar, "W"); \
    BOOL isWeak = weak != NULL; \
    id associatedValue = nil; \
    if (isWeak) { \
        NSMapTable *weakAssociated = objc_getAssociatedObject(slf, _Hotfix_Property_WeakAssociatedKey); \
        associatedValue = [weakAssociated objectForKey:propertyName]; \
    } else { \
        NSMutableDictionary *defaultAssociated = objc_getAssociatedObject(slf, _Hotfix_Property_DefaultAssociatedKey); \
        associatedValue = defaultAssociated[propertyName]; \
        char * copy = property_copyAttributeValue(ivar, "C"); \
        BOOL isCopy = copy != NULL; \
        if (isCopy) { \
            associatedValue = [associatedValue copy]; \
        } \
    } \
    \
    _getter_code \
    \
    return rtnValue; \
}


#pragma mark Case
#define _HOTFIX_PROPERTY_SETTER_CASE_CODE \
id value = @(newValue);

#define _HOTFIX_PROPERTY_GETTER_CASE_CODE(_typeString, _case_getCode) \
_typeString rtnValue = [associatedValue _case_getCode];

#define _HOTFIX_PROPERTY_CASE(_typeString, _typeName, _case_getCode, _default_return) \
_HOTFIX_PROPERTY_METHOD(_typeString, _typeName, _HOTFIX_PROPERTY_SETTER_CASE_CODE, _HOTFIX_PROPERTY_GETTER_CASE_CODE(_typeString, _case_getCode), _default_return)


#pragma mark SEL
#define _HOTFIX_PROPERTY_SETTER_SEL_CODE \
id value = newValue ? NSStringFromSelector(newValue) : nil;

#define _HOTFIX_PROPERTY_GETTER_SEL_CODE(_typeString) \
_typeString rtnValue = [(NSString *)associatedValue length] ? NSSelectorFromString(associatedValue) : NULL;

#define _HOTFIX_PROPERTY_SEL(_typeString, _default_return) \
_HOTFIX_PROPERTY_METHOD(_typeString, _typeString, _HOTFIX_PROPERTY_SETTER_SEL_CODE, _HOTFIX_PROPERTY_GETTER_SEL_CODE(_typeString), _default_return)


#pragma mark Instance
#define _HOTFIX_PROPERTY_SETTER_INSTANCE_CODE \
id value = newValue;

#define _HOTFIX_PROPERTY_GETTER_INSTANCE_CODE(_typeString) \
_typeString rtnValue = associatedValue;

#define _HOTFIX_PROPERTY_INSTANCE(_typeString, _default_return) \
_HOTFIX_PROPERTY_METHOD(_typeString, _typeString, _HOTFIX_PROPERTY_SETTER_INSTANCE_CODE, _HOTFIX_PROPERTY_GETTER_INSTANCE_CODE(_typeString), _default_return)


#pragma mark Struct
#define _HOTFIX_PROPERTY_SETTER_STRUCT_CODE(_struct_setCode) \
NSValue *value = [NSValue _struct_setCode:newValue];

#define _HOTFIX_PROPERTY_GETTER_STRUCT_CODE(_typeString, _struct_getCode) \
_typeString rtnValue = [associatedValue _struct_getCode];

#define _HOTFIX_PROPERTY_STRUCT(_typeString, _struct_setCode, _struct_getCode, _default_return) \
_HOTFIX_PROPERTY_METHOD(_typeString, _typeString, _HOTFIX_PROPERTY_SETTER_STRUCT_CODE(_struct_setCode), _HOTFIX_PROPERTY_GETTER_STRUCT_CODE(_typeString, _struct_getCode), _default_return)


#pragma mark - Declear
_HOTFIX_PROPERTY_CASE(BOOL, BOOL, boolValue, false)
_HOTFIX_PROPERTY_CASE(int, int, intValue, 0)
_HOTFIX_PROPERTY_CASE(char, char, charValue,0)
_HOTFIX_PROPERTY_CASE(short, short, shortValue, 0)
_HOTFIX_PROPERTY_CASE(unsigned short, unsignedshort, unsignedShortValue, 0)
_HOTFIX_PROPERTY_CASE(unsigned int, unsignedint, unsignedIntValue, 0)
_HOTFIX_PROPERTY_CASE(long, long, longValue, 0)
_HOTFIX_PROPERTY_CASE(unsigned long, unsignedlong, unsignedLongValue, 0)
_HOTFIX_PROPERTY_CASE(long long, longlong, longLongValue, 0)
_HOTFIX_PROPERTY_CASE(unsigned long long, unsignedlonglong, unsignedLongLongValue, 0)
_HOTFIX_PROPERTY_CASE(float, float, floatValue, 0.0f)
_HOTFIX_PROPERTY_CASE(double, double, doubleValue, 0.0)
_HOTFIX_PROPERTY_CASE(CGFloat, CGFloat, doubleValue, 0.0)
_HOTFIX_PROPERTY_CASE(NSInteger, NSInteger, integerValue, 0)
_HOTFIX_PROPERTY_CASE(NSUInteger, NSUInteger, unsignedIntegerValue, 0)

_HOTFIX_PROPERTY_SEL(SEL, NULL)

_HOTFIX_PROPERTY_INSTANCE(id, nil)
_HOTFIX_PROPERTY_INSTANCE(Class, nil)

_HOTFIX_PROPERTY_STRUCT(CGRect, valueWithCGRect, CGRectValue, CGRectZero)
_HOTFIX_PROPERTY_STRUCT(CGPoint, valueWithCGPoint, CGPointValue, CGPointZero)
_HOTFIX_PROPERTY_STRUCT(CGSize, valueWithCGSize, CGSizeValue, CGSizeZero)
_HOTFIX_PROPERTY_STRUCT(NSRange, valueWithRange, rangeValue, NSMakeRange(NSNotFound, 0))


#endif /* HotfixPropertyStoreMethod_h */
