//
// Created by Larry Tin on 2017/5/31.
//

#import <Foundation/Foundation.h>

@class GDOPBDelta;
@class GDORichText;

@protocol GDOEditor <NSObject>

+ (GDORichText *(^)(UIView *view))attachView;

- (GDOPBDelta *(^)(GDOPBDelta *delta))applyDelta;

- (GDOPBDelta *)delta;

@end