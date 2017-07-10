//
// Created by Larry Tin on 2017/5/31.
//

#import <objc/runtime.h>
#import "GDOLabel.h"
#import "GoodowOperation.pbobjc.h"
#import "GDOPBDelta+GDOperation.h"
#import "GDOAttributedStringUtil.h"
#import "GDORichText.h"

static const char kRichTextKey = 0;

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
    _attributedText = [[NSMutableAttributedString alloc] init];
    _delta = GDOPBDelta.message.insert(@"\n", nil);
    objc_setAssociatedObject(_label, &kRichTextKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
      [self appendLine:line];
      [self appendNewParagraph:attributes];
      return YES;
  }, nil);
}

- (void)appendLine:(GDOPBDelta *)delta {
  for (GDOPBDelta_Operation *op in delta.opsArray) {
    if (!op.insert.length && !op.hasInsertEmbed) {
      return;
    }
    NSAttributedString *string = nil;
    if (op.insert.length) {
      NSString *text = op.insert;
      NSDictionary *attr = [GDOAttributedStringUtil parseInlineAttributes:op.attributes toRemove:nil];
      string = [[NSAttributedString alloc] initWithString:text attributes:attr];
    } else if (op.insertEmbed.image.length) {
      __weak typeof(self) weakSelf = self;
      string = [self.class createImageEmbed:op downloadCompletionHandler:^{
          dispatch_async(dispatch_get_main_queue(), ^{
              [weakSelf update];
          });
      }];
    } else if (op.insertEmbed.space) {
      string = [self.class createSpaceEmbed:op];
    }
    if (string) {
      [self.attributedText appendAttributedString:string];
    }
  }
}

- (void)appendNewParagraph:(GDOPBAttribute *)attribute {
  NSUInteger length = self.attributedText.length;
  NSRange range = [self.attributedText.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, length)];
  long lineStart = 0;
  if (range.location != NSNotFound) {
    lineStart = range.location + 1;
  }
  [self.attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  if ([GDOAttributedStringUtil parseBlockAttributes:attribute style:paragraphStyle]) {
    [self.attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(lineStart, length + 1 - lineStart)];
  }
}

+ (NSAttributedString *)createImageEmbed:(GDOPBDelta_Operation *)op downloadCompletionHandler:(void (^)())completionHandler {
  NSString *imageString = op.insertEmbed.image;
  NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
  UIImage *image = [UIImage imageNamed:imageString];
  if (image) {
    textAttachment.image = image;
  } else {
    NSURL *url = [NSURL URLWithString:imageString];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
          return;
        }
        textAttachment.image = [UIImage imageWithData:data];
        if (completionHandler) {
          completionHandler();
        }
    }];
    [task resume];
  }
  CGFloat width = [GDOAttributedStringUtil sizeFromString:op.attributes.width];
  CGFloat height = [GDOAttributedStringUtil sizeFromString:op.attributes.height];
  if (width && height) {
    textAttachment.bounds = CGRectMake(0, 0, width, height);
  }
  NSAttributedString *string = [NSAttributedString attributedStringWithAttachment:textAttachment];
  if (op.attributes.link.length) {
    NSMutableAttributedString *mutableCopy = string.mutableCopy;
    [mutableCopy addAttribute:Link_Attribute value:op.attributes.link range:NSMakeRange(0, 1)];
    return mutableCopy;
  }
  return string;
}

+ (NSAttributedString *)createSpaceEmbed:(GDOPBDelta_Operation *)op {
  CGFloat width = [GDOAttributedStringUtil sizeFromString:op.attributes.width];
  CGFloat height = [GDOAttributedStringUtil sizeFromString:op.attributes.height];
  if (width <= 0 && height <= 0) {
    return nil;
  }
  NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
  textAttachment.image = [UIImage new];
  textAttachment.bounds = CGRectMake(0, 0, width ?: 0.1, height ?: 0.1);
  return [NSAttributedString attributedStringWithAttachment:textAttachment];
}

- (void)update {
  self.label.attributedText = nil; // force to update
  if ([self.attributedText.string hasSuffix:@"\n"]) {
    [self.attributedText deleteCharactersInRange:NSMakeRange(self.attributedText.string.length - 1, 1)];
  }
  self.label.attributedText = self.attributedText;
}
@end