//
//  HotfixComponent.m
//  Hotfix
//
//  Created by nate on 2021/1/21.
//

#import "HotfixComponent.h"

#import <UIKit/UIKit.h>

#import "HotfixJsAdapter.h"
#import "HotfixLogDefined.h"

#define HotfixComponentDebug    1

#define HotfixComponentEncryptKey   @""
#define HotfixComponentEncryptIv    @""

static NSString * const kHotfixComponentFileDirectory = @"hf_jsContent";

@interface HotfixComponent ()

@property (nonatomic, strong) HotfixJsAdapter *jsAdapter;

// patch info
@property (nonatomic, strong) NSDictionary *patchInfo;
@property (nonatomic, strong) NSString *patchContent;

// 当前正在运行的js版本号
@property (nonatomic, assign) NSInteger currentVersion;

// 从后台唤醒时，触发缓存js
@property (nonatomic, strong) NSString *activeJs;
@property (nonatomic, assign) BOOL shouldExecuteJsWhileActive;

@end

@implementation HotfixComponent

+ (void)registerComponent {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // regist at app launch
        [HotfixComponent sharedInstance];
    });
}

+ (instancetype)sharedInstance {
    static HotfixComponent *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[HotfixComponent alloc] init];
    });
    
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.currentVersion = -1;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [self configureLocalJS];
    }
    return self;
}

#pragma mark Become Active
- (void)didBecomeActive {
    
}

#pragma mark Property
- (HotfixJsAdapter *)jsAdapter {
    @synchronized (self) {
        if (!_jsAdapter) {
            _jsAdapter = HotfixJsAdapter.new;
        }
    }
    return _jsAdapter;
}

#pragma mark File
- (void)configureLocalJS {
    
#ifdef DEBUG
#if HotfixComponentDebug
    NSString *debugFilePath = [[NSBundle mainBundle] pathForResource:@"patch" ofType:@"js"];
    NSError *err;
    NSString *jsContent = [NSString stringWithContentsOfFile:debugFilePath encoding:NSUTF8StringEncoding error:&err];
    
    void (^block)(void) = ^ {
        [self.jsAdapter runJS:jsContent completion:^(BOOL succeed) {
            NSLog(@"js 执行： %d", succeed);
        }];
    };
    
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    }
    
    return;
#endif
#endif
    
}


@end
