//
// Created by Larry Tin on 12/11/16.
//

#import <Foundation/Foundation.h>
#import "GoodowOperation.pbobjc.h"
#import "GDOPBAttribute+FluentInterface.h"

extern const NSString *NULL_SENTINEL_CHARACTER;
#define NULL_ENUM_VALUE 15

@interface GDOPBDelta (GDOperation)

- (GDOPBDelta *(^)(NSString *text, GDOPBAttribute *attributes))insert;

- (GDOPBDelta *(^)(unsigned long long length, GDOPBAttribute *attributes))retain_p;

- (GDOPBDelta *(^)(unsigned long long length))delete;

- (GDOPBDelta *(^)(GDOPBDelta *other))compose;

- (void (^)(BOOL (^predicate)(GDOPBDelta *line, GDOPBAttribute *attributes, int i), NSString *newline))eachLine;

- (unsigned long long)length;

@end