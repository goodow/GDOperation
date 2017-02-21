//
//  GDOTableViewCellProtocol.h
//  GDOperation
//
//  Created by alonsolu on 2017/2/21.
//  Copyright © 2017年 Larry Tin. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GDOPBDelta;
@protocol GDOTableViewCellProtocol <NSObject>
- (void)applyPatch:(GDOPBDelta *)delta;
@end
