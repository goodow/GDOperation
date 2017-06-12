//
//  GDOTableViewCell.m
//  GDOperation
//
//  Created by Larry Tin on 2016/12/10.
//  Copyright © 2016年 Larry Tin. All rights reserved.
//

#import "GDOTableViewCell.h"
#import "GoodowOperation.pbobjc.h"
#import "NSObject+GDChannel.h"
#import "GDCBusProvider.h"
#import "GPBMessage+JsonFormat.h"
#import "GDORichText.h"
#import "GDOLabel.h"

@interface GDOTableViewCell ()
@property(weak, nonatomic) IBOutlet UILabel *richText;

@end

@implementation GDOTableViewCell

- (void)awakeFromNib {
  [super awakeFromNib];
  // Initialization code
  [self subscribe];
}

- (void)applyPatch:(GDOPBDelta *)delta {
  GDOLabel.attachView(self.richText).updateContents(delta);
}

- (void)subscribe {
  __weak GDOTableViewCell *weakSelf = self;
  [self.bus subscribe:[NSString stringWithFormat:@"%@/", GDCBusProvider.clientId, @"richText555"] handler:^(id <GDCMessage> message) {
      NSDictionary *payload = message.payload;
      GDOPBDelta *delta = [GDOPBDelta parseFromJson:payload error:nil];
      [weakSelf applyPatch:delta];
  }];
}
@end