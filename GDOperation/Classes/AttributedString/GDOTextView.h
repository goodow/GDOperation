//
// Created by Larry Tin on 2017/5/31.
//

#import <Foundation/Foundation.h>
#import "GDOEditor.h"

@class GDOPBDelta_Operation;

@interface GDOTextView : NSObject <GDOEditor>

+ (GDORichText *(^)(UITextView *textView))attachView;

+ (NSAttributedString *)parseInsertText:(GDOPBDelta_Operation *)op;

+ (NSAttributedString *)parseInsertNewParagraph:(NSMutableAttributedString *)attributedText at:(long)cursor op:(GDOPBDelta_Operation *)op;

+ (void)retainText:(NSMutableAttributedString *)attributedText at:(long)cursor op:(GDOPBDelta_Operation *)op;

+ (void)retainParagraph:(NSMutableAttributedString *)attributedText at:(long)cursor op:(GDOPBDelta_Operation *)op;

+ (void)publishLinkClick:(NSURL *)url;
@end