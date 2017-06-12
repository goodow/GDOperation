//
//  GDOTextViewTableViewCell.m
//  GDOperation
//
//  Created by alonsolu on 2017/2/21.
//  Copyright © 2017年 Larry Tin. All rights reserved.
//

#import "GDOTextViewTableViewCell.h"
#import "GDORichText.h"
#import "GDOTextView.h"

@interface GDOTextViewTableViewCell ()
@property (weak, nonatomic) IBOutlet UITextView *textView;
@end

@implementation GDOTextViewTableViewCell {

}

- (void)awakeFromNib {
  [super awakeFromNib];
  // Initialization code
  _textView.editable = NO;
}

- (void)applyPatch:(GDOPBDelta *)delta {
  GDOTextView.attachView(self.textView).updateContents(delta);
}

@end
