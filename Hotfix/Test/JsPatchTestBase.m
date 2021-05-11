//
//  JsPatchTestBase.m
//  Hotfix
//
//  Created by Near Kong on 2021/5/11.
//

#import "JsPatchTestBase.h"

@implementation JsPatchTestBase

- (void)dealloc {
    NSLog(@"-- JsPatchTestBase -- dealloc --");
}

+ (BOOL)testB:(BOOL)b {
    NSLog(@"-- class -- testB: %d", b);
    return !b;
}

- (BOOL)testB:(BOOL)b {
    NSLog(@"-- instance -- testB: %d", b);
    return !b;
}

+ (NSInteger)testI:(NSInteger)i {
    NSLog(@"-- class -- testI: %ld", i);
    return i + 100;
}

- (NSInteger)testI:(NSInteger)i {
    NSLog(@"-- instance -- testI: %ld", i);
    return i + 100;
}

+ (CGFloat)testF:(CGFloat)f {
    NSLog(@"-- class -- testF: %f", f);
    return f + 100;
}

- (CGFloat)testF:(CGFloat)f {
    NSLog(@"-- instance -- testF: %f", f);
    return f + 100;
}

+ (NSString *)testS:(NSString *)s {
    NSLog(@"-- class -- testS: %@", s);
    return [NSString stringWithFormat:@"this S: %@", s];
}

- (NSString *)testS:(NSString *)s {
    NSLog(@"-- instance -- testS: %@", s);
    return [NSString stringWithFormat:@"this S: %@", s];
}

+ (NSString *)testBlock:(NSString * (^)(NSInteger i0, CGFloat f0, NSString *s0, NSInteger i1, CGFloat f1, NSString *s1))block {
    NSLog(@"-- class -- testBlock: %@", block);
    NSString *rtn = @"No result";
    if (block) {
        rtn = block(1, 2.5, @"3", 4, 5.5, @"6");
    }
    return rtn;
}

- (NSString *)testBlock:(NSString * (^)(NSInteger i0, CGFloat f0, NSString *s0, NSInteger i1, CGFloat f1, NSString *s1))block {
    NSLog(@"-- instance -- testBlock: %@", block);
    NSString *rtn = @"No result";
    if (block) {
        rtn = block(1, 2.5, @"3", 4, 5.5, @"6");
    }
    return rtn;
}

+ (NSString *)testAsyncBlock:(NSString * (^)(NSInteger i0, CGFloat f0, NSString *s0, NSInteger i1, CGFloat f1, NSString *s1))block {
    NSLog(@"-- class -- testAsyncBlock: %@", block);
    NSString *rtn = @"No result";
    if (block) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *rtn = block(1, 2.5, @"3", 4, 5.5, @"6");
            NSLog(@"-- instance -- testAsyncBlock result: %@", rtn);
        });
    }
    return rtn;
}

- (NSString *)testAsyncBlock:(NSString * (^)(NSInteger i0, CGFloat f0, NSString *s0, NSInteger i1, CGFloat f1, NSString *s1))block {
    NSLog(@"-- instance -- testAsyncBlock: %@", block);
    NSString *rtn = @"No result";
    if (block) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *rtn = block(1, 2.5, @"3", 4, 5.5, @"6");
            NSLog(@"-- instance -- testAsyncBlock result: %@", rtn);
        });
    }
    return rtn;
}

+ (NSMutableDictionary *)testMD:(NSMutableDictionary *)mutableD {
    mutableD[@"test"] = @"test";
    return mutableD;
}

- (NSMutableDictionary *)testMD:(NSMutableDictionary *)mutableD {
    mutableD[@"test"] = @"test";
    return mutableD;
}

- (void)method1:(NSString *)method name:(NSString *)name age:(NSUInteger)age {
    NSLog(@"name: %@, age: %lu", name, (unsigned long)age);
}

@end
