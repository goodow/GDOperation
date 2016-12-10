//
// Created by Larry Tin on 12/11/16.
//

#import <Foundation/Foundation.h>
#import "GoodowOperation.pbobjc.h"
#import "GDOPBAttribute+FluentInterface.h"

@interface GDOPBDelta (GDOperation)

- (GDOPBDelta *(^)(NSString *text, GDOPBAttribute *attributes))insert;

- (GDOPBDelta *(^)(unsigned long long length, GDOPBAttribute *attributes))retain_p;

- (GDOPBDelta *(^)(unsigned long long length))delete;


@end