//
// Created by Larry Tin on 12/11/16.
//

#import "GDOPBDelta+GDOperation.h"

@implementation GDOPBDelta (GDOperation)

- (GDOPBDelta *(^)(NSString *text, GDOPBAttribute *attributes))insert {
  return ^GDOPBDelta *(NSString *text, GDOPBAttribute *attributes) {
      GDOPBOperation *op = [[GDOPBOperation alloc] init];
      op.insert = text;
      op.attributes = attributes;
      [self.opsArray addObject:op];
      return self;
  };
}

- (GDOPBDelta *(^)(unsigned long long, GDOPBAttribute *))retain_p {
  return ^GDOPBDelta *(unsigned long long int length, GDOPBAttribute *attributes) {
      GDOPBOperation *op = [[GDOPBOperation alloc] init];
      op.retain_p = length;
      op.attributes = attributes;
      [self.opsArray addObject:op];
      return self;
  };
}

- (GDOPBDelta *(^)(unsigned long long))delete {
  return ^GDOPBDelta *(unsigned long long int length) {
      GDOPBOperation *op = [[GDOPBOperation alloc] init];
      op.delete_p = length;
      [self.opsArray addObject:op];
      return self;
  };
}


@end