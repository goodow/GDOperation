//
// Created by Larry Tin on 2016/12/10.
// Copyright (c) 2016 Larry Tin. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GDOPBDelta;


@interface GDOModel : NSObject

@property (nonatomic, strong) NSMutableArray<GDOPBDelta *> *dataSource;

@end