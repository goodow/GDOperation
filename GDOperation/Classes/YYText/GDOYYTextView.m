//
// Created by Larry Tin on 2017/5/31.
//

#import <objc/runtime.h>
#import "GDOYYTextView.h"
#import "GoodowOperation.pbobjc.h"
#import "GDCBusProvider.h"
#import "NSObject+GDChannel.h"
#import "GDOAttributedStringUtil.h"
#import "GDORichText.h"

#import "NSAttributedString+YYText.h"
#import "GDOLabel.h"
#import "GDOTextView.h"

static const char kRichTextKey = 0;

@interface GDOYYTextView () <YYTextViewDelegate>
@property(nonatomic, weak) YYTextView *textView;
@property(nonatomic, readonly) NSMutableAttributedString *attributedText;
@property(nonatomic, strong) GDOPBDelta *delta;

@end

@implementation GDOYYTextView {

}

+ (GDORichText *(^)(YYTextView *textView))attachView {
  return ^GDORichText *(YYTextView *textView) {
      return [[GDORichText alloc] initWithEditor:[[GDOYYTextView alloc] initWithTextView:textView]];
  };
}

- (instancetype)initWithTextView:(YYTextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _textView.delegate = self;
    _attributedText = [[NSMutableAttributedString alloc] initWithString:@"\n"];
    _delta = GDOPBDelta.message.insert(@"\n", nil);
    objc_setAssociatedObject(_textView, &kRichTextKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

- (void)apply:(GDOPBDelta *)delta {
  long cursor = 0;
  for (GDOPBDelta_Operation *op in delta.opsArray) { // 遍历富文本片段
    if (op.insert.length) { // 有文本信息
      NSString *text = op.insert;
      NSAttributedString *string = nil;
      if (![text isEqualToString:@"\n"]) { // 不是换行段落
        string = [GDOTextView parseInsertText:op];
        if (op.attributes.link.length) {
          self.textView.linkTextAttributes = [string attributesAtIndex:0 effectiveRange:NULL];
        }
      } else { // 换行段落
        string = [GDOTextView.class parseInsertNewParagraph:self.attributedText at:cursor op:op];
      }
      [self.attributedText insertAttributedString:string atIndex:cursor];
      cursor += text.length;
      continue;
    }

    if (op.retain_p > 0) {
      if ([self.attributedText.string characterAtIndex:cursor] != '\n') {
        [GDOTextView.class retainText:self.attributedText at:cursor op:op];
      } else {
        [GDOTextView.class retainParagraph:self.attributedText at:cursor op:op];
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
      } else if (op.insertEmbed.button.length) {
        NSString *imageName;
        UIButton *button = [UIButton new];
        imageName = op.insertEmbed.button;
        [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        if ([GDOAttributedStringUtil sizeFromString:op.attributes.width] && [GDOAttributedStringUtil sizeFromString:op.attributes.height]) {
          button.bounds = CGRectMake(0, 0, [GDOAttributedStringUtil sizeFromString:op.attributes.width], [GDOAttributedStringUtil sizeFromString:op.attributes.height]);
        }
        YYTextAttachment *attach = [[YYTextAttachment alloc] init];
        attach.content = button;
        if ([op.attributes.link length]) {
          objc_setAssociatedObject(button, &kRichTextKey, op.attributes.link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        attach.contentMode = UIViewContentModeCenter;


        NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:YYTextAttachmentToken];
        [attrStr yy_setTextAttachment:attach range:NSMakeRange(0, attrStr.length)];
        string = attrStr;
        UIImage *image = [UIImage imageNamed:imageName];
        if (image) {
          [self setImage:image withView:button];
        } else {
          NSURL *url = [NSURL URLWithString:imageName];
          __weak typeof(self) weakSelf = self;
          __weak typeof(button) weakView = button;
          NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              if (!error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf setImage:[UIImage imageWithData:data] withView:weakView];
                    [weakSelf update];
                });
              } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    //view.image = [UIImage new];
                    [weakSelf update];
                });
              }
          }];
          [task resume];
        }
      }
      if (string) {
        [self.attributedText insertAttributedString:string atIndex:cursor];
      }
      cursor += 1;
    }
  }
}

- (void)setImage:(UIImage *)image withView:(UIView *)view {
  if ([view isKindOfClass:[UIImageView class]]) {
    [(UIImageView *) view setImage:image];
  } else {
    [(UIButton *) view setBackgroundImage:image forState:UIControlStateNormal];
  }
}

- (void)update {
  self.textView.attributedText = nil; // force to update
  self.textView.attributedText = self.attributedText;
}

#pragma mark - YYTextViewDelegate

//按钮回调
- (void)buttonClicked:(UIButton *)btn {
  NSString *attachLink = objc_getAssociatedObject(btn, &kRichTextKey);
  if ([attachLink length]) {
    NSString *clientId = [GDCBusProvider clientId];
    NSString *topic = [NSString stringWithFormat:@"%@/actions/views", clientId];
    [self.bus publishLocal:topic payload:attachLink];
  }
}

//- (void)textViewDidChangeSelection:(YYTextView *)textView {
//  // 该方法禁止textView被select时的高亮（因为[textView:shouldInteractWithURL:inRange:]方法必须在textView是selectable时生效）
//  if (!NSEqualRanges(textView.selectedRange, NSMakeRange(0, 0))) {
//    textView.selectedRange = NSMakeRange(0, 0);
//  }
//}
@end