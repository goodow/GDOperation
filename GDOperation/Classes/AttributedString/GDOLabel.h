//
// Created by Larry Tin on 2017/5/31.
//

#import <Foundation/Foundation.h>
#import "GDOEditor.h"

@class GDOPBDelta_Operation;

@interface GDOLabel : NSObject <GDOEditor>

+ (GDORichText *(^)(UILabel *label))attachView;

+ (NSAttributedString *)createSpaceEmbed:(GDOPBDelta_Operation *)op;
@end