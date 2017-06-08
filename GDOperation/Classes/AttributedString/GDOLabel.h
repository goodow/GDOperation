//
// Created by Larry Tin on 2017/5/31.
//

#import <Foundation/Foundation.h>
#import "GDOEditor.h"

static NSString *const Link_Attribute = @"gdo.link";
@class GDOPBDelta_Operation;

@interface GDOLabel : NSObject <GDOEditor>

+ (GDORichText *(^)(UILabel *label))attachView;

+ (NSAttributedString *)createImageEmbed:(GDOPBDelta_Operation *)op downloadCompletionHandler:(void (^)())completionHandler;

+ (NSAttributedString *)createSpaceEmbed:(GDOPBDelta_Operation *)op;
@end