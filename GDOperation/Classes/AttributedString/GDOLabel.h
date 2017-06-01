//
// Created by Larry Tin on 2017/5/31.
//

#import <Foundation/Foundation.h>
#import "GDOEditor.h"

@interface GDOLabel : NSObject <GDOEditor>

+ (GDORichText *(^)(UILabel *label))attachView;

@end