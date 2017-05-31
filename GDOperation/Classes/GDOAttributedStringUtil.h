//
// Created by Larry Tin on 2017/5/31.
//

#import <Foundation/Foundation.h>

@class GDOPBAttribute;


@interface GDOAttributedStringUtil : NSObject

+ (NSDictionary<NSString *, id> *)parseInlineAttributes:(GDOPBAttribute *)attributes toRemove:(NSArray **)toRemovePtr;

+ (BOOL)parseBlockAttributes:(GDOPBAttribute *)attributes style:(NSMutableParagraphStyle *)paragraph;

+ (CGFloat)sizeFromString:(NSString *)size;
@end