//
//  NSInvocation+Hotfix.m
//  Hotfix
//
//  Created by nate on 2020/12/27.
//

#import "NSInvocation+Hotfix.h"

#import <UIKit/UIKit.h>

#import <JavaScriptCore/JavaScriptCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "HotfixInvocationMacro.h"
#import "HotfixPointerContainer.h"

@implementation NSInvocation (Hotfix)

/// 获取入参
/// @param jsContext JSContext 用于设置 JSValue
- (NSArray *)hf_getArguments:(JSContext *)jsContext {
    BOOL isBlock = [[self.target class] isSubclassOfClass:NSClassFromString(@"NSBlock")];
    NSMethodSignature *methodSignature = [self methodSignature];
    NSInteger numberOfArguments = [methodSignature numberOfArguments];
    
    NSMutableArray *argesList = [[NSMutableArray alloc] init];
    for (NSUInteger i = isBlock ? 1 : 2; i < numberOfArguments; i++) {
        const char *argumentType = [methodSignature getArgumentTypeAtIndex:i];
        switch(argumentType[0] == 'r' ? argumentType[1] : argumentType[0]) {

            #define HF_GET_ARG_CASE(_typeChar, _type) \
            case _typeChar: {   \
                _type arg;  \
                [self getArgument:&arg atIndex:i];    \
                JSValue *jsVal = [JSValue valueWithObject:@(arg) inContext:jsContext]; \
                [argesList addObject:(jsVal ?: @(arg))]; \
                break;  \
            }
            HF_GET_ARG_CASE('c', char)
            HF_GET_ARG_CASE('C', unsigned char)
            HF_GET_ARG_CASE('s', short)
            HF_GET_ARG_CASE('S', unsigned short)
            HF_GET_ARG_CASE('i', int)
            HF_GET_ARG_CASE('I', unsigned int)
            HF_GET_ARG_CASE('l', long)
            HF_GET_ARG_CASE('L', unsigned long)
            HF_GET_ARG_CASE('q', long long)
            HF_GET_ARG_CASE('Q', unsigned long long)
            HF_GET_ARG_CASE('f', float)
            HF_GET_ARG_CASE('d', double)
            HF_GET_ARG_CASE('B', BOOL)
                
            case '@': {
                __autoreleasing id arg;
                [self getArgument:&arg atIndex:i];
                if ([arg isKindOfClass:NSNull.class]) {
                    arg = Hotfix_Invocation_JsNull;
                }
                JSValue *jsVal = [JSValue valueWithObject:arg inContext:jsContext];
                [argesList addObject:(jsVal ?: arg ?: NSNull.null)];
                break;
            }
                
            case '{': {
                NSString *typeString = Hotfix_Invocation_StructName([NSString stringWithUTF8String:argumentType]);
                #define HF_GET_ARG_STRUCT(_type, _transFunc, _valFunc) \
                if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
                    _type arg; \
                    [self getArgument:&arg atIndex:i];    \
                    JSValue *jsVal = [JSValue _transFunc:arg inContext:jsContext];\
                    [argesList addObject:(jsVal ?: [NSValue _valFunc:arg])];  \
                    break; \
                }
                HF_GET_ARG_STRUCT(CGRect, valueWithRect, valueWithCGRect)
                HF_GET_ARG_STRUCT(CGPoint, valueWithPoint, valueWithCGPoint)
                HF_GET_ARG_STRUCT(CGSize, valueWithSize, valueWithCGSize)
                HF_GET_ARG_STRUCT(NSRange, valueWithRange, valueWithRange)
                                  
                [argesList addObject:NSNull.null];
                break;
            }
                
            case ':': {
                SEL selector;
                [self getArgument:&selector atIndex:i];
                NSString *selectorName = NSStringFromSelector(selector);
                JSValue *jsVal = [JSValue valueWithObject:selectorName inContext:jsContext];
                [argesList addObject:(jsVal ?: selectorName ?: NSNull.null)];
                break;
            }
                
            case '^':
            case '*': {
                void *arg;
                JSValue *jsVal;
                [self getArgument:&arg atIndex:i];
                if (arg) {
                    HotfixPointerContainer *container = [HotfixPointerContainer containerWithPointer:arg];
                    jsVal = [JSValue valueWithObject:container inContext:jsContext];
                }
                [argesList addObject:(jsVal ?: NSNull.null)];
                break;
            }
                
            case '#': {
                Class arg;
                [self getArgument:&arg atIndex:i];
                JSValue *jsVal = [JSValue valueWithObject:arg inContext:jsContext];
                [argesList addObject:(jsVal ?: arg ?: NSNull.null)];
                break;
            }
                
            default: {
                [argesList addObject:NSNull.null];
                NSLog(@"error type %s", argumentType);
                break;
            }
        }
    }
    
    return argesList;
}


/// 获取返参
/// @param jsContext jsContext JSContext 用于设置 JSValue
- (nullable JSValue *)hf_getReturnValue:(JSContext *)jsContext {
    if (!jsContext) {
        NSAssert(false, @"jsContext 为空");
        return nil;
    }
    
    char returnType[255];
    NSMethodSignature *methodSignature = self.methodSignature;
    strcpy(returnType, [methodSignature methodReturnType]);
    
    // Restore the return type
    if (strcmp(returnType, @encode(Hotfix_Invocation_DoubleType)) == 0) {
        strcpy(returnType, @encode(double));
    }
    if (strcmp(returnType, @encode(Hotfix_Invocation_FloatType)) == 0) {
        strcpy(returnType, @encode(float));
    }

    id returnValue;
    if (strncmp(returnType, "v", 1) == 0) {
        return nil;
    }
    
    if (strncmp(returnType, "@", 1) == 0) {
        void *result;
        [self getReturnValue:&result];
        
        NSString *selectorName = NSStringFromSelector(self.selector);
        //For performance, ignore the other methods prefix with alloc/new/copy/mutableCopy
        if ([selectorName isEqualToString:@"alloc"] || [selectorName isEqualToString:@"new"] ||
            [selectorName isEqualToString:@"copy"] || [selectorName isEqualToString:@"mutableCopy"]) {
            returnValue = (__bridge_transfer id)result;
        } else {
            returnValue = (__bridge id)result;
        }
        
        if ([returnValue isKindOfClass:NSNull.class]) {
            returnValue = Hotfix_Invocation_JsNull;
        }
        
        return [JSValue valueWithObject:returnValue inContext:jsContext];
        
    } else {
        switch (returnType[0] == 'r' ? returnType[1] : returnType[0]) {
                
            // 这里有点问题，类型不匹配，但是js内部转换应该可以处理
            #define HF_GET_RET_CASE(_typeString, _type) \
                case _typeString: {                              \
                    _type tempResultSet; \
                    [self getReturnValue:&tempResultSet];\
                    returnValue = [JSValue valueWithObject:@(tempResultSet) inContext:jsContext]; \
                    break; \
                }
            
            HF_GET_RET_CASE('c', char)
            HF_GET_RET_CASE('C', unsigned char)
            HF_GET_RET_CASE('s', short)
            HF_GET_RET_CASE('S', unsigned short)
            HF_GET_RET_CASE('i', int)
            HF_GET_RET_CASE('I', unsigned int)
            HF_GET_RET_CASE('l', long)
            HF_GET_RET_CASE('L', unsigned long)
            HF_GET_RET_CASE('q', long long)
            HF_GET_RET_CASE('Q', unsigned long long)
            HF_GET_RET_CASE('f', float)
            HF_GET_RET_CASE('d', double)
            HF_GET_RET_CASE('B', BOOL)
                
            case '{': {
                NSString *typeString = Hotfix_Invocation_StructName([NSString stringWithUTF8String:returnType]);
                #define HF_GET_RET_STRUCT(_type, _methodName) \
                if ([typeString rangeOfString:@#_type].location != NSNotFound) {    \
                    _type result;   \
                    [self getReturnValue:&result];    \
                    returnValue = [JSValue _methodName:result inContext:jsContext];    \
                    break; \
                }
                
                HF_GET_RET_STRUCT(CGRect, valueWithRect)
                HF_GET_RET_STRUCT(CGPoint, valueWithPoint)
                HF_GET_RET_STRUCT(CGSize, valueWithSize)
                HF_GET_RET_STRUCT(NSRange, valueWithRange)
                break;
            }
                
            case '*':
            case '^': {
                void *result;
                [self getReturnValue:&result];
                if (result) {
                    HotfixPointerContainer *container = [HotfixPointerContainer containerWithPointer:result];
                    returnValue = [JSValue valueWithObject:container inContext:jsContext];
                }
                break;
            }
                
            case '#': {
                Class result;
                [self getReturnValue:&result];
                returnValue = [JSValue valueWithObject:result inContext:jsContext];
                break;
            }
                
            case ':': {
                SEL result;
                [self getReturnValue:&result];
                returnValue = [JSValue valueWithObject:NSStringFromSelector(result) inContext:jsContext];
                break;
            }
        }
        
        return returnValue;
    }
    
    return nil;
}

@end

