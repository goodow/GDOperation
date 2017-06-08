//
// Created by Larry Tin on 2017/5/31.
//

#import <objc/runtime.h>
#import "GDOTextView.h"
#import "GoodowOperation.pbobjc.h"
#import "GDCBusProvider.h"
#import "NSObject+GDChannel.h"
#import "GDOAttributedStringUtil.h"
#import "GDORichText.h"
#import "GDOLabel.h"

static const char kGDOTextViewKey = 0;

@interface GDOTextView () <UITextViewDelegate>
@property(nonatomic, weak) UITextView *textView;
@property(nonatomic, readonly) NSMutableAttributedString *attributedText;
@property(nonatomic, strong) GDOPBDelta *delta;

@end

@implementation GDOTextView {

}

+ (GDORichText *(^)(UITextView *textView))attachView {
  return ^GDORichText *(UITextView *textView) {
      return [[GDORichText alloc] initWithEditor:[[GDOTextView alloc] initWithTextView:textView]];
  };
}

- (instancetype)initWithTextView:(UITextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _textView.delegate = self;
    _attributedText = [[NSMutableAttributedString alloc] initWithString:@"\n"];
    _delta = GDOPBDelta.message.insert(@"\n", nil);
    objc_setAssociatedObject(_textView, &kGDOTextViewKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return self;
}

- (GDOPBDelta *(^)(GDOPBDelta *delta))applyDelta {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
      [self apply:delta];
      [self update];
      self.delta = self.delta.compose(delta);
      return delta;
  };
}

#pragma mark - Internal methods

// 根据delta更新attributedText
- (void)apply:(GDOPBDelta *)delta {
  long cursor = 0;
  for (GDOPBDelta_Operation *op in delta.opsArray) { // 遍历富文本片段
    if (op.insert.length) { // 有文本信息
      NSString *text = op.insert;
      NSAttributedString *string = nil;
      if (![text isEqualToString:@"\n"]) { // 不是换行段落
        string = [self insertText:op];
      } else { // 换行段落
        string = [self insertNewParagraph:cursor op:op];
      }
      [self.attributedText insertAttributedString:string atIndex:cursor];
      cursor += text.length;
      continue;
    }

    if (op.retain_p > 0) {
      if ([self.attributedText.string characterAtIndex:cursor] != '\n') {
        [self retainText:cursor op:op];
      } else {
        [self retainParagraph:cursor op:op];
      }
      cursor += op.retain_p;
      continue;
    }

    if (op.delete_p > 0) {
      [self.attributedText deleteCharactersInRange:NSMakeRange(cursor, op.delete_p)];
      continue;
    }

    if (op.hasInsertEmbed) {
      NSAttributedString *string = nil;
      if (op.insertEmbed.image.length) {
        __weak typeof(self) weakSelf = self;
        string = [GDOLabel createImageEmbed:op downloadCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf update];
            });
        }];
      } else if (op.insertEmbed.space) {
        string = [GDOLabel createSpaceEmbed:op];
      }
      if (string) {
        [self.attributedText insertAttributedString:string atIndex:cursor];
      }
      cursor += 1;
    }
  }
}

- (NSAttributedString *)insertText:(GDOPBDelta_Operation *)op {
  NSDictionary *attr = [GDOAttributedStringUtil parseInlineAttributes:op.attributes toRemove:nil];
  if (op.attributes.link.length) {
    self.textView.linkTextAttributes = attr;
  }
  return [[NSAttributedString alloc] initWithString:op.insert attributes:attr];
}

- (void)retainText:(long)cursor op:(GDOPBDelta_Operation *)op {
  NSArray *toRemove;
  NSDictionary<NSString *, id> *attrs = [GDOAttributedStringUtil parseInlineAttributes:op.attributes toRemove:&toRemove];
  if (attrs.count) {
    [self.attributedText addAttributes:attrs range:NSMakeRange(cursor, op.retain_p)];
  }
  for (NSString *key in toRemove) {
    [self.attributedText removeAttribute:key range:NSMakeRange(cursor, op.retain_p)];
  }
}

- (NSAttributedString *)insertNewParagraph:(long)cursor op:(GDOPBDelta_Operation *)op {
  NSRange range = [self.attributedText.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, cursor)];
  long lineStart = 0;
  if (range.location != NSNotFound) {
    lineStart = range.location + 1;
  }
  [self.attributedText insertAttributedString:[[NSAttributedString alloc] initWithString:@"\n"] atIndex:cursor];
  NSMutableParagraphStyle *paragraphStyle = nil;
  if (cursor && lineStart < self.attributedText.length) {
    paragraphStyle = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:lineStart longestEffectiveRange:nil inRange:NSMakeRange(lineStart, 1)];
  }
  paragraphStyle = paragraphStyle ? paragraphStyle.mutableCopy : [[NSMutableParagraphStyle alloc] init];
  if ([GDOAttributedStringUtil parseBlockAttributes:op.attributes style:paragraphStyle]) {
    [self.attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(lineStart, cursor - lineStart)];
  }
  return [[NSAttributedString alloc] initWithString:@"\n" attributes:@{NSParagraphStyleAttributeName : paragraphStyle}];
}

- (void)retainParagraph:(long)cursor op:(GDOPBDelta_Operation *)op {
  NSRange range = [self.attributedText.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, cursor == 0 ? 0 : cursor - 1)];
  long lineStart = 0;
  if (range.location != NSNotFound) {
    lineStart = range.location + 1;
  }
  NSMutableParagraphStyle *paragraphStyle = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:lineStart longestEffectiveRange:nil inRange:NSMakeRange(lineStart, 1)];
  paragraphStyle = paragraphStyle ? paragraphStyle.mutableCopy : [[NSMutableParagraphStyle alloc] init];
  if ([GDOAttributedStringUtil parseBlockAttributes:op.attributes style:paragraphStyle]) {
    [self.attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(lineStart, cursor - lineStart + 1)];
  }
}

- (void)update {
  self.textView.attributedText = nil; // force to update
  self.textView.attributedText = self.attributedText;
}


+ (void)publishLinkClick:(NSString *)url {
  NSString *topic = [NSString stringWithFormat:@"%@/actions/views", GDCBusProvider.clientId];
  [self.bus publishLocal:topic payload:url];
}

#pragma mark - UITextViewDelegate

// textView回调，用于跳转富文本中的超链接
- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)url inRange:(NSRange)characterRange {
  [self.class publishLinkClick:url.absoluteString];
  return NO;
}

- (BOOL)textView:(UITextView *)textView shouldInteractWithTextAttachment:(NSTextAttachment *)textAttachment inRange:(NSRange)characterRange {
  NSString *attachLink = [self.attributedText attribute:Link_Attribute atIndex:characterRange.location longestEffectiveRange:nil inRange:characterRange];
  if (attachLink.length) {
    [self.class publishLinkClick:attachLink];
  }
  return NO;
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  // 该方法禁止textView被select时的高亮（因为[textView:shouldInteractWithURL:inRange:]方法必须在textView是selectable时生效）
  if (!NSEqualRanges(textView.selectedRange, NSMakeRange(0, 0))) {
    textView.selectedRange = NSMakeRange(0, 0);
  }
}
@end
