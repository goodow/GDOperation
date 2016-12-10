//
// Created by Larry Tin on 2016/12/10.
//

#import <Foundation/Foundation.h>
#import "GDOPBDelta+GDOperation.h"
#import "GDOPBAttribute+FluentInterface.h"

@class GDOPBDelta;

@interface GDORichText : NSObject

- (instancetype)initWithLabel:(UILabel *)label;

#pragma mark - Content

- (GDOPBDelta *(^)(GDOPBDelta *delta))updateContents;
- (GDOPBDelta *(^)(NSRange range))getContents;
- (GDOPBDelta *(^)(GDOPBDelta *delta))setContents;
- (NSString *(^)(NSRange range))getText;
- (GDOPBDelta *(^)(NSString *text))setText;
- (GDOPBDelta *(^)(NSRange range))deleteText;
- (GDOPBDelta *(^)(unsigned long long index, NSString *text, GDOPBAttribute *attributes))insertText;
- (unsigned long long(^)())getLength;

#pragma mark - Formatting

- (GDOPBAttribute *(^)(NSRange range))getFormat;
- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatText;
- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatLine;
- (GDOPBDelta *(^)(NSRange range))removeFormat;

@end