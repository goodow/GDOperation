//
// Created by Larry Tin on 2017/5/31.
//

#import <objc/runtime.h>
#import "GDOTextView.h"
#import "UITextView+GDORichText.h"
#import "GoodowOperation.pbobjc.h"
#import "GDCBusProvider.h"
#import "NSObject+GDChannel.h"
#import "GDOAttributedStringUtil.h"
#import "GDORichText.h"

static const char kAttachmentKey = 0;

@interface GDOTextView () <UITextViewDelegate>
@property(nonatomic, weak) UITextView *textView;
@property(nonatomic, readonly) NSMutableAttributedString *attributedText;
@property (nonatomic, strong) GDOPBDelta *delta;

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
    _textView.richText = self; // 增加richtext属性
    _attributedText = textView.attributedText.mutableCopy;
    _delta = GDOPBDelta.message;
  }
  return self;
}

- (GDOPBDelta *(^)(GDOPBDelta *delta))applyDelta {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
      [self apply:delta];
      [self update];
      return nil;
  };
}

#pragma mark - Internal methods

// 根据delta更新attributedText
- (void)apply:(GDOPBDelta *)delta {
  long cursor = 0;
  for (GDOPBDelta_Operation *op in delta.opsArray) { // 遍历富文本片段
    if (op.insert.length) { // 有文本信息
      NSString *text = op.insert;
      if (![text isEqualToString:@"\n"]) { // 不是换行段落
        NSDictionary *attr = [GDOAttributedStringUtil parseInlineAttributes:op.attributes];
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:attr];
        [self.attributedText insertAttributedString:str atIndex:cursor];
        if (op.attributes.link.length) {
          self.textView.linkTextAttributes = attr;
        }
      } else { // 换行段落
        NSRange range = [self.attributedText.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, cursor)];
        long lineStart = 0;
        if (range.location != NSNotFound) {
          lineStart = range.location + 1;
        }
        NSMutableParagraphStyle *paragraphStyle;
        if (cursor && ((lineStart + 1) < [self.attributedText length])) {
          paragraphStyle = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:lineStart longestEffectiveRange:nil inRange:NSMakeRange(lineStart, 1)];
        }
        [self.attributedText insertAttributedString:[[NSAttributedString alloc] initWithString:text attributes:paragraphStyle] atIndex:cursor];
        paragraphStyle = paragraphStyle ? paragraphStyle.mutableCopy : [[NSMutableParagraphStyle alloc] init];
        if ([GDOAttributedStringUtil parseBlockAttributes:op.attributes style:paragraphStyle]) {
          [self.attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(lineStart, cursor - lineStart + 1)];
        }
      }
      cursor += text.length;
      continue;
    }

    if (op.retain_p > 0) {
      if ([self.attributedText.string characterAtIndex:cursor] != '\n') {
        NSDictionary<NSString *, id> *attrs = [GDOAttributedStringUtil parseInlineAttributes:op.attributes];
        if (attrs.count) {
          [self.attributedText addAttributes:attrs range:NSMakeRange(cursor, op.retain_p)];
        }
      } else {
        NSRange range = [self.attributedText.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, cursor == 0 ? 0 : cursor - 1)];
        long lineStart = 0;
        if (range.location != NSNotFound) {
          lineStart = range.location + 1;
        }
        NSMutableParagraphStyle *paragraphStyle = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:lineStart longestEffectiveRange:nil inRange:NSMakeRange(lineStart, 1)];
        if ([GDOAttributedStringUtil parseBlockAttributes:op.attributes style:paragraphStyle ? paragraphStyle.mutableCopy : [[NSMutableParagraphStyle alloc] init]]) {
          [self.attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(lineStart, cursor - lineStart + 1)];
        }
      }
      cursor += op.retain_p;
      continue;
    }

    if (op.delete_p > 0) {
      [self.attributedText deleteCharactersInRange:NSMakeRange(cursor, op.delete_p)];
      continue;
    }

    if (op.hasInsertEmbed) {
      if (op.insertEmbed.space) {
        if (([GDOAttributedStringUtil sizeFromString:op.attributes.width] > 0) || ([GDOAttributedStringUtil sizeFromString:op.attributes.height] > 0)) {
          NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
          textAttachment.image = [UIImage new];
          CGFloat width = [GDOAttributedStringUtil sizeFromString:op.attributes.width] ?: 0.1;
          CGFloat height = [GDOAttributedStringUtil sizeFromString:op.attributes.height] ?: 0.1;
          textAttachment.bounds = CGRectMake(0, 0, width, height);
          if ([op.attributes.link length]) {
            objc_setAssociatedObject(textAttachment, &kAttachmentKey, op.attributes.link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
          }
          NSAttributedString *attr9 = [NSAttributedString attributedStringWithAttachment:textAttachment];
          [self.attributedText insertAttributedString:attr9 atIndex:cursor];
          cursor += 1;
        }
      } else if (op.insertEmbed.image || op.insertEmbed.button) {
        NSString *imageName = op.insertEmbed.image ?: op.insertEmbed.button;
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        UIImage *image = [UIImage imageNamed:imageName];
        if (image) {
          textAttachment.image = image;
        } else {
          NSURL *url = [NSURL URLWithString:imageName];
          __weak typeof(self) weakSelf = self;
          NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              if (!error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    textAttachment.image = [UIImage imageWithData:data];
                    [weakSelf update];
                });
              } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    textAttachment.image = [UIImage new];
                    [weakSelf update];
                });
              }
          }];
          [task resume];
        }
        if ([GDOAttributedStringUtil sizeFromString:op.attributes.width] && [GDOAttributedStringUtil sizeFromString:op.attributes.height]) {
          textAttachment.bounds = CGRectMake(0, 0, [GDOAttributedStringUtil sizeFromString:op.attributes.width], [GDOAttributedStringUtil sizeFromString:op.attributes.height]);
        }


        if ([op.attributes.link length]) {
          objc_setAssociatedObject(textAttachment, &kAttachmentKey, op.attributes.link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NSAttributedString *attr9 = [NSAttributedString attributedStringWithAttachment:textAttachment];
        [self.attributedText insertAttributedString:attr9 atIndex:cursor];
        cursor += 1;
        // other implementation
        //        cursor += 1;
      } else if (op.insertEmbed.video) {
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        textAttachment.image = [UIImage imageNamed:op.insertEmbed.video];
        textAttachment.contents = [UIImage imageNamed:op.insertEmbed.video];
        NSAttributedString *attr9 = [NSAttributedString attributedStringWithAttachment:textAttachment];
        [self.attributedText insertAttributedString:attr9 atIndex:cursor];
        cursor += 1;

        // other implementation
        //        cursor += 1;
      }
      continue;
    }
  }
}

- (void)update {
  self.textView.attributedText = nil; // force to update
  self.textView.attributedText = self.attributedText;
}


#pragma mark - UITextViewDelegate

// textView回调，用于跳转富文本中的超链接
- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)url inRange:(NSRange)characterRange {
  NSString *topic = [NSString stringWithFormat:@"%@/actions/views", GDCBusProvider.clientId];
  [self.bus publishLocal:topic payload:url.absoluteString];
  return NO;
}

- (BOOL)textView:(UITextView *)textView shouldInteractWithTextAttachment:(NSTextAttachment *)textAttachment inRange:(NSRange)characterRange {
  NSString *attachLink = objc_getAssociatedObject(textAttachment, &kAttachmentKey);
  if ([attachLink length]) {
    NSString *clientId = [GDCBusProvider clientId];
    NSString *topic = [NSString stringWithFormat:@"%@/actions/views", clientId];
    [self.bus publishLocal:topic payload:attachLink];
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