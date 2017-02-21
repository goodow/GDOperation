//
//  GDOTextViewTableViewCell.m
//  GDOperation
//
//  Created by alonsolu on 2017/2/21.
//  Copyright © 2017年 Larry Tin. All rights reserved.
//

#import "GDOTextViewTableViewCell.h"
#import "GDORichText.h"

@interface GDOTextViewTableViewCell ()
@property (weak, nonatomic) IBOutlet UITextView *textView;
@end

@implementation GDOTextViewTableViewCell {
  GDORichText *_richText;
}

- (void)awakeFromNib {
  [super awakeFromNib];
  // Initialization code
  _textView.editable = NO;
}

- (void)applyPatch:(GDOPBDelta *)delta {
  _richText = [[GDORichText alloc] initWithTextView:_textView]; // 强引用，不然textView的回调不起作用
  _richText.updateContents(delta);
}

@end
