//
//  JsPatchTestBase.h
//  Hotfix
//
//  Created by Near Kong on 2021/5/11.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface JsPatchTestBase : NSObject

+ (BOOL)testB:(BOOL)b;
- (BOOL)testB:(BOOL)b;

+ (NSInteger)testI:(NSInteger)i;
- (NSInteger)testI:(NSInteger)i;

+ (CGFloat)testF:(CGFloat)f;
- (CGFloat)testF:(CGFloat)f;

+ (NSString *)testS:(NSString *)s;
- (NSString *)testS:(NSString *)s;

+ (NSString *)testBlock:(NSString * (^)(NSInteger i0, CGFloat f0, NSString *s0, NSInteger i1, CGFloat f1, NSString *s1))block;
- (NSString *)testBlock:(NSString * (^)(NSInteger i0, CGFloat f0, NSString *s0, NSInteger i1, CGFloat f1, NSString *s1))block;

+ (NSString *)testAsyncBlock:(NSString * (^)(NSInteger i0, CGFloat f0, NSString *s0, NSInteger i1, CGFloat f1, NSString *s1))block;
- (NSString *)testAsyncBlock:(NSString * (^)(NSInteger i0, CGFloat f0, NSString *s0, NSInteger i1, CGFloat f1, NSString *s1))block;

+ (NSMutableDictionary *)testMD:(NSMutableDictionary *)mutableD;
- (NSMutableDictionary *)testMD:(NSMutableDictionary *)mutableD;

- (void)method1:(NSString *)method name:(NSString *)name age:(NSUInteger)age;

@end

NS_ASSUME_NONNULL_END
