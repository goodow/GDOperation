//
// Created by Larry Tin on 2017/5/30.
//

#import <Foundation/Foundation.h>

@class FIRDatabaseReference;
@class GDOPBDelta;

@interface GDOFirebaseAdapter : NSObject

@property void (^onTextChange)(GDOPBDelta *delta, GDOPBDelta *contents);

- (instancetype)initWithRef:(FIRDatabaseReference *)ref;

+ (NSString *)revisionToId:(unsigned long long)revision;

+ (unsigned long long)revisionFromId:(NSString *)revisionId;
@end