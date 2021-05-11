//
//  HotfixPointerContainer.h
//  Hotfix
//
//  Created by nate on 2021/2/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HotfixPointerContainer : NSObject {
    @public
    void *_pointer;
}

+ (instancetype)containerWithPointer:(void *)pointer;


@end

NS_ASSUME_NONNULL_END
