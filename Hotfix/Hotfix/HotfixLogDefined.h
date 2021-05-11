//
//  HotfixLogDefined.h
//  Hotfix
//
//  Created by nate on 2021/1/18.
//

#ifndef HotfixLogDefined_h
#define HotfixLogDefined_h

/// 记录异常
/// @param msg 信息
/// @param stack 堆栈
static void Hotfix_LogJsException(id _Nullable msg, id _Nullable stack) {
#if DEBUG
    if (!stack) {
        stack = NSThread.callStackSymbols;
    }
#endif
    
    NSString *failLog = [NSString stringWithFormat:@"Javascript exception:\n  %@; \nstack:\n  %@;", msg, stack];
    NSLog(@"%@", failLog);
    NSCAssert(false, failLog);
}


#endif /* HotfixLogDefined_h */
