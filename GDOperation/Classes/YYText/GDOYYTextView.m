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

#import "YYTextView.h"
#import "NSAttributedString+YYText.h"

static const char kAttachmentKey = 0;
static const char kRichTextKey = 0;

@interface GDOYYTextView () <YYTextViewDelegate>
@property(nonatomic, weak) YYTextView *textView;
@property(nonatomic, readonly) NSMutableAttributedString *attributedText;
@property (nonatomic, strong) GDOPBDelta *delta;

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
    objc_setAssociatedObject(_textView, &kRichTextKey,self , OBJC_ASSOCIATION_RETAIN_NONATOMIC);//让view持有self,避免被释放掉
    _attributedText = [[NSMutableAttributedString alloc] initWithString:@"\n"];
    _delta = GDOPBDelta.message.insert(@"\n", nil);
  }
  return self;
}
-(void)dealloc{
  NSLog(@"dellocate");
}
- (GDOPBDelta *(^)(GDOPBDelta *delta))applyDelta {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
    [self apply:delta];
    [self update];
    self.delta = self.delta.compose(delta);
    return nil;
  };
}
-(void)setImage:(UIImage*)image withView:(UIView*)view{
  if ([view isKindOfClass:[UIImageView class]]) {
    [(UIImageView*)view setImage:image];
  } else {
    [(UIButton*)view setBackgroundImage:image forState:UIControlStateNormal];
  }
}
#pragma mark - Internal methods

// 根据delta更新attributedText
- (void)apply:(GDOPBDelta *)delta {
  long cursor = 0;
  for (GDOPBDelta_Operation *op in delta.opsArray) { // 遍历富文本片段
    if (op.insert.length) { // 有文本信息
      NSString *text = op.insert;
      if (![text isEqualToString:@"\n"]) { // 不是换行段落
        NSDictionary *attr = [GDOAttributedStringUtil parseInlineAttributes:op.attributes toRemove:nil];
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
        [self.attributedText insertAttributedString:[[NSAttributedString alloc] initWithString:@"\n"] atIndex:cursor];
        NSMutableParagraphStyle *paragraphStyle = nil;
        if (cursor && ((lineStart) < self.attributedText.length)) {
          paragraphStyle = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:lineStart longestEffectiveRange:nil inRange:NSMakeRange(lineStart, 1)];
        }
        paragraphStyle = paragraphStyle ? paragraphStyle.mutableCopy : [[NSMutableParagraphStyle alloc] init];
        if ([GDOAttributedStringUtil parseBlockAttributes:op.attributes style:paragraphStyle]) {
          [self.attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(lineStart, cursor + 1 - lineStart)];
        }
      }
      cursor += text.length;
      continue;
    }

    if (op.retain_p > 0) {
      if ([self.attributedText.string characterAtIndex:cursor] != '\n') {
        NSArray *toRemove;
        NSDictionary<NSString *, id> *attrs = [GDOAttributedStringUtil parseInlineAttributes:op.attributes toRemove:&toRemove];
        if (attrs.count) {
          [self.attributedText addAttributes:attrs range:NSMakeRange(cursor, op.retain_p)];
        }
        for (NSString *key in toRemove) {
          [self.attributedText removeAttribute:key range:NSMakeRange(cursor, op.retain_p)];
        }
      } else {
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
        NSString *imageName;
        UIView *view ;
        if ([op.insertEmbed.image length]) {
          imageName = op.insertEmbed.image;
          view = [UIImageView new];
          view.userInteractionEnabled = YES;
          UITapGestureRecognizer *tap =[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageTaped:)];
          [view addGestureRecognizer:tap];
        } else {
          imageName = op.insertEmbed.button;
          view = [UIButton new];
          [(UIButton*)view addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        }
        if ([GDOAttributedStringUtil sizeFromString:op.attributes.width]&& [GDOAttributedStringUtil sizeFromString:op.attributes.height]) {
          view.bounds = CGRectMake(0, 0,[GDOAttributedStringUtil sizeFromString:op.attributes.width] , [GDOAttributedStringUtil sizeFromString:op.attributes.height]);
        }
        YYTextAttachment *attach = [[YYTextAttachment alloc] init];
        attach.content = view;
        if ([op.attributes.link length]) {
          objc_setAssociatedObject(view, &kAttachmentKey, op.attributes.link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        attach.contentMode = UIViewContentModeCenter;


        NSMutableAttributedString *attr9 = [[NSMutableAttributedString alloc] initWithString:YYTextAttachmentToken];
        [attr9 yy_setTextAttachment:attach range:NSMakeRange(0, attr9.length)];
        UIImage *image = [UIImage imageNamed:imageName];
        if (image) {
          [self setImage:image withView:view];
        } else {
          NSURL *url = [NSURL URLWithString:imageName];
          __weak typeof(self) weakSelf = self;
          __weak typeof(view) weakView = view;
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

        [self.attributedText insertAttributedString:attr9 atIndex:cursor];
        cursor += 1;
      }
      continue;
    }
  }
}

- (void)update {
  self.textView.attributedText = nil; // force to update
  self.textView.attributedText = self.attributedText;
}


#pragma mark - YYTextViewDelegate

// textView回调，用于跳转富文本中的超链接
- (BOOL)textView:(YYTextView *)textView shouldInteractWithURL:(NSURL *)url inRange:(NSRange)characterRange {
  NSString *topic = [NSString stringWithFormat:@"%@/actions/views", GDCBusProvider.clientId];
  [self.bus publishLocal:topic payload:url.absoluteString];
  return NO;
}

//按钮回调
-(void)buttonClicked:(UIButton*)btn{
  NSString *attachLink = objc_getAssociatedObject(btn, &kAttachmentKey);
  if ([attachLink length]) {
    NSString *clientId = [GDCBusProvider clientId];
    NSString *topic = [NSString stringWithFormat:@"%@/actions/views", clientId];
    [self.bus publishLocal:topic payload:attachLink];
  }
}

//iamge回调
-(void)imageTaped:(UITapGestureRecognizer*)tap{
  NSString *attachLink = objc_getAssociatedObject([tap view], &kAttachmentKey);
  if ([attachLink length]) {
    NSString *clientId = [GDCBusProvider clientId];
    NSString *topic = [NSString stringWithFormat:@"%@/actions/views", clientId];
    [self.bus publishLocal:topic payload:attachLink];
  }
}

- (void)textViewDidChangeSelection:(YYTextView *)textView {
  // 该方法禁止textView被select时的高亮（因为[textView:shouldInteractWithURL:inRange:]方法必须在textView是selectable时生效）
  if (!NSEqualRanges(textView.selectedRange, NSMakeRange(0, 0))) {
    textView.selectedRange = NSMakeRange(0, 0);
  }
}
@end
