//
//  HotfixInvocationMacro.h
//  Hotfix
//
//  Created by nate on 2021/1/19.
//

#ifndef HotfixInvocationMacro_h
#define HotfixInvocationMacro_h

typedef struct {double d;} Hotfix_Invocation_DoubleType;
typedef struct {float f;} Hotfix_Invocation_FloatType;

extern NSObject * Hotfix_Invocation_JsNull;

/// 解析结构体名称
/// @param typeEncodeString 参数类型
static NSString * Hotfix_Invocation_StructName(NSString *typeEncodeString) {
    NSArray *array = [typeEncodeString componentsSeparatedByString:@"="];
    NSString *typeString = array[0];
    int firstValidIndex = 0;
    for (int i = 0; i< typeString.length; i++) {
        char c = [typeString characterAtIndex:i];
        if (c == '{' || c=='_') {
            firstValidIndex++;
        }else {
            break;
        }
    }
    return [typeString substringFromIndex:firstValidIndex];
}


#endif /* HotfixInvocationMacro_h */
