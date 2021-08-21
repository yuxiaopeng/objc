//
//  FindMinMaxThread.m
//  objc
//
//  Created by roc on 2021/8/21.
//

#import "FindMinMaxThread.h"

@implementation FindMinMaxThread {
    NSArray *_numbers;
}

- (instancetype)initWithNumbers:(NSArray *)numbers {
    self = [super init];
    if (self) {
        _numbers = numbers;
    }
    return self;
}

- (void)main {
    NSUInteger min;
    NSUInteger max;
    // 进行相关的数据处理
    self.min = min;
    self.max = max;
}

@end
