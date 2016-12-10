//
// Created by Larry Tin on 2016/12/10.
// Copyright (c) 2016 Larry Tin. All rights reserved.
//

#import "GDOModel.h"
#import "GoodowOperation.pbobjc.h"
#import "GDOPBDelta+GDOperation.h"

@implementation GDOModel {

}
- (instancetype)init {
  self = [super init];
  if (self) {
    _dataSource = @[].mutableCopy;
    GDOPBDelta *delta = [GDOPBDelta message];
    GDOPBAttribute *attribute = [GDOPBAttribute message]
        .setBold(GDOPBAttribute_Bool_True).setItalic(GDOPBAttribute_Bool_False);
//        .setSize(@"22px");
    delta.insert(@"Label", attribute);
    _dataSource[0] = delta;
  }

  return self;
}

@end