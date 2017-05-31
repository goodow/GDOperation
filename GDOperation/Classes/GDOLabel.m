//
// Created by Larry Tin on 2017/5/31.
//

#import <objc/runtime.h>
#import "GDOLabel.h"
#import "GoodowOperation.pbobjc.h"
#import "GDOPBDelta+GDOperation.h"
#import "GDOAttributedStringUtil.h"
#import "GDORichText.h"

static const char kAttachmentKey = 0;

@interface GDOLabel ()
@property(nonatomic, readonly) NSMutableAttributedString *attributedText;
@property(nonatomic, weak) UILabel *label;
@property(nonatomic, strong) GDOPBDelta *delta;
@end

@implementation GDOLabel {

}
+ (GDORichText *(^)(UILabel *label))attachView {
  return ^GDORichText *(UILabel *label) {
      return [[GDORichText alloc] initWithEditor:[[self alloc] initWithLabel:label]];
  };
}

- (instancetype)initWithLabel:(UILabel *)label {
  self = [super init];
  if (self) {
    _label = label;
    _attributedText = label.attributedText.mutableCopy ?: [NSMutableAttributedString new];
    _delta = GDOPBDelta.message;
  }

  return self;
}

- (GDOPBDelta *(^)(GDOPBDelta *delta))applyDelta {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
      if (!delta) {
        return nil;
      }
      [self apply:delta];
      [self update];
      return nil;
  };
}

- (void)apply:(GDOPBDelta *)delta {
  self.delta = self.delta.compose(delta);
  self.delta.eachLine(^BOOL(GDOPBDelta *line, GDOPBAttribute *attributes, int i) {
      [self appendOneLine:line];
      [self appendNewParagraphwithAttribute:attributes];
      return YES;
  }, nil);
}

- (void)appendOneLine:(GDOPBDelta *)delta {
  for (GDOPBDelta_Operation *op in delta.opsArray) {
    if (!op.insert.length && !op.hasInsertEmbed) {
      return;
    }
    if (op.insert.length) {
      NSString *text = op.insert;
      NSDictionary *attr = [GDOAttributedStringUtil parseInlineAttributes:op.attributes];
      NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:attr];
      [self.attributedText appendAttributedString:str];
      continue;
    }

    if (op.insertEmbed.image) {
      NSString *imageName = op.insertEmbed.image;
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
      [self.attributedText appendAttributedString:attr9];
    } else if (op.insertEmbed.space) {
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
        [self.attributedText appendAttributedString:attr9];
      }
    }
  }
}

- (void)appendNewParagraphwithAttribute:(GDOPBAttribute *)attribute {
  NSUInteger length = self.attributedText.length;
  NSRange range = [self.attributedText.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, length)];
  long lineStart = 0;
  if (range.location != NSNotFound) {
    lineStart = range.location + 1;
  }
  NSMutableParagraphStyle *paragraphStyle;
  if ((lineStart + 1) < length) {
    paragraphStyle = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:lineStart longestEffectiveRange:nil inRange:NSMakeRange(lineStart, 1)];
  }
  [self.attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:paragraphStyle]];
  paragraphStyle = paragraphStyle ? paragraphStyle.mutableCopy : [[NSMutableParagraphStyle alloc] init];
  if ([GDOAttributedStringUtil parseBlockAttributes:attribute style:paragraphStyle]) {
    [self.attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(lineStart, length + 1 - lineStart)];
  }
}

- (void)update {
  self.label.attributedText = nil; // force to update
  if ([self.attributedText.string hasSuffix:@"\n"]) {
    [self.attributedText deleteCharactersInRange:NSMakeRange(self.attributedText.string.length - 1, 1)];
  }
  self.label.attributedText = self.attributedText;
}
@end