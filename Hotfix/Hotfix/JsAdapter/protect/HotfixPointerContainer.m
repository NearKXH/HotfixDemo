//
//  HotfixPointerContainer.m
//  Hotfix
//
//  Created by nate on 2021/2/17.
//

#import "HotfixPointerContainer.h"

@implementation HotfixPointerContainer

- (void)dealloc {
    CFRelease(_pointer);
}

+ (instancetype)containerWithPointer:(void *)pointer {
    HotfixPointerContainer *container = HotfixPointerContainer.new;
    container->_pointer = pointer;
    CFRetain(pointer);
    return container;
}


@end
