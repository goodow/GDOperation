//
// Created by Larry Tin on 2016/12/10.
//

#import "GDORichText.h"
#import "NSObject+GDChannel.h"
#import "GDCBusProvider.h"
#import "UITextView+GDORichText.h"
#import <objc/runtime.h>

static const char kAttachmentKey = 0;

@interface GDORichText () <UITextViewDelegate>
@property(nonatomic, readonly) NSMutableAttributedString *attributedText;
@property(nonatomic, weak) UILabel *label;
@property(nonatomic, weak) UITextView *textView;
@end

@implementation GDORichText {
}

// 以label初始化
- (instancetype)initWithLabel:(UILabel *)label {
  self = [super init];
  if (self) {
    _label = label;
    _attributedText = label.attributedText.mutableCopy?:[NSMutableAttributedString new];
    if (!_attributedText.length) { // 所有的delta以\n结尾
      self.setText(@"\n");
    }
  }

  return self;
}

// 以textview初始化
- (instancetype)initWithTextView:(UITextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _textView.delegate = self;
    _textView.richText = self; // 增加richtext属性
    _attributedText = textView.attributedText.mutableCopy;
    if (!_attributedText.length) {
      self.setText(@"\n");
    }
  }
  return self;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _attributedText = [[NSMutableAttributedString alloc] initWithString:@"\n"];
  }

  return self;
}

#pragma mark - Content

// 更新content
- (GDOPBDelta *(^)(GDOPBDelta *delta))updateContents {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
      [self apply:delta];
      [self update];
      return nil;
  };
}

// 获取content
- (GDOPBDelta *(^)(NSRange range))getContents {
  return ^GDOPBDelta *(NSRange range) {
      return nil;
  };
}

// 设置content,先清除content，再更新content
- (GDOPBDelta *(^)(GDOPBDelta *delta))setContents {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
      NSUInteger length = self.attributedText.length;
      [self.attributedText deleteCharactersInRange:NSMakeRange(0, length)];
      GDOPBDelta *contents = self.updateContents(delta);
      if (self.label) {
        NSInteger stringLength = [self.attributedText.string length];
        if (stringLength>1) {
          NSString *checkn = [self.attributedText.string substringFromIndex:stringLength-1];
          if ([checkn isEqualToString:@"\n"]) {
            [self.attributedText deleteCharactersInRange:NSMakeRange(stringLength-1, 1)];
            [self update];
          }
        }
      }
      //      return contents.delete(length);
      return nil;
  };
}

// 获取文本
- (NSString *(^)(NSRange range))getText {
  return ^NSString *(NSRange range) {
      NSString *string = self.attributedText.string;
      return string.length ? string : @"\n";
  };
}

// 设置文本
- (GDOPBDelta *(^)(NSString *text))setText {
  return ^GDOPBDelta *(NSString *text) {
      NSUInteger length = self.attributedText.length;
      [self.attributedText replaceCharactersInRange:NSMakeRange(0, length) withString:text]; // 替换文本
      [self update]; // 更新label和textview的属性
      return [GDOPBDelta message].insert(text, nil).delete(length); // 构造了一个用于返回的delta
  };
}

// 删除文本
- (GDOPBDelta *(^)(NSRange range))deleteText {
  return ^GDOPBDelta *(NSRange range) {
      [self.attributedText deleteCharactersInRange:range];
      [self update];
      return [GDOPBDelta message].retain_p(range.location, nil).delete(range.length);
  };
}

// 插入文本
- (GDOPBDelta *(^)(unsigned long long index, NSString *text, GDOPBAttribute *attributes))insertText {
  return ^GDOPBDelta *(unsigned long long int index, NSString *text, GDOPBAttribute *attributes) {
      NSAttributedString *string = [[NSAttributedString alloc] initWithString:text attributes:[self parseInlineAttributes:attributes]];
      [self.attributedText insertAttributedString:string atIndex:index];
      [self update];
      return [GDOPBDelta message].retain_p(index, nil).insert(text, attributes);
  };
}

// 获取AttributedString长度
- (unsigned long long (^)())getLength {
  return ^unsigned long long int {
      return self.attributedText.length ?: 1;
  };
}

#pragma mark - Formatting

// 获取range范围内的样式,取出来的是NSDictionary，需要转为GDOPBAttribute
- (GDOPBAttribute *(^)(NSRange range))getFormat {
  return ^GDOPBAttribute *(NSRange range) {
      NSRange r;
      NSDictionary<NSString *, id> *attr = [self.attributedText attributesAtIndex:range.location effectiveRange:&r];
      if (r.length != range.length) {
        return [self parseNSAttributes:attr];
      }
      return NULL;
  };
}

- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatText {
  return ^GDOPBDelta *(NSRange range, GDOPBAttribute *attributes) {
      NSDictionary<NSString *, id> *attr = [self parseInlineAttributes:attributes];
      [self.attributedText addAttributes:attr range:range];
      [self update];
      return nil;
  };
}

- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatLine {
  return ^GDOPBDelta *(NSRange range, GDOPBAttribute *attributes) {
      [self update];
      return nil;
  };
}

- (GDOPBDelta *(^)(NSRange range))removeFormat {
  return ^GDOPBDelta *(NSRange range) {
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
        NSDictionary *attr = [self parseInlineAttributes:op.attributes];
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
        if ([self parseBlockAttributes:op.attributes style:paragraphStyle]) {
          [self.attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(lineStart, cursor - lineStart + 1)];
        }
      }
      cursor += text.length;
      continue;
    }

    if (op.retain_p > 0) {
      if ([self.attributedText.string characterAtIndex:cursor] != '\n') {
        NSDictionary<NSString *, id> *attrs = [self parseInlineAttributes:op.attributes];
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
        if ([self parseBlockAttributes:op.attributes style:paragraphStyle ? paragraphStyle.mutableCopy : [[NSMutableParagraphStyle alloc] init]]) {
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
        if (([self _sizeFromString:op.attributes.width] > 0) || ([self _sizeFromString:op.attributes.height] > 0)) {
          NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
          textAttachment.image = [UIImage new];
          CGFloat width = [self _sizeFromString:op.attributes.width]?:0.1;
          CGFloat height = [self _sizeFromString:op.attributes.height]?:0.1;
          textAttachment.bounds = CGRectMake(0, 0,width , height);
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
        if ([self _sizeFromString:op.attributes.width]&& [self _sizeFromString:op.attributes.height]) {
          textAttachment.bounds = CGRectMake(0, 0,[self _sizeFromString:op.attributes.width] , [self _sizeFromString:op.attributes.height]);
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


// GDOPBAttribute样式集合转为NSAttribute的属性的字典 针对单个文字
- (NSDictionary<NSString *, id> *)parseInlineAttributes:(GDOPBAttribute *)attributes {
  NSMutableDictionary<NSString *, id> *attrs = @{}.mutableCopy;
  if (attributes.color.length) {
    attrs[NSForegroundColorAttributeName] = [self _colorFromHex:attributes.color];
  }
  if (attributes.background.length) {
    attrs[NSBackgroundColorAttributeName] = [self _colorFromHex:attributes.background];
  }
  if (attributes.size.length || attributes.font.length) {
    //    UIFont *font = [self.attributedText attribute:NSFontAttributeName atIndex:<#(NSUInteger)location#> effectiveRange:nil];
    UIFont *font = [UIFont fontWithName:attributes.font.length ? attributes.font : @"Helvetica" size:[self _sizeFromString:attributes.size]];
    attrs[NSFontAttributeName] = font;
  }
  if (attributes.link.length) {
    attrs[NSLinkAttributeName] = attributes.link;
  }
  if (attributes.bold) {
    attrs[NSExpansionAttributeName] = @(attributes.bold == GDOPBAttribute_Bool_True ? 0.2 : 0);
  }
  if (attributes.italic) {
    attrs[NSObliquenessAttributeName] = @(attributes.italic == GDOPBAttribute_Bool_True ? 0.3 : 0);
  }
  if (attributes.underline) {
    attrs[NSUnderlineStyleAttributeName] = @(attributes.underline == GDOPBAttribute_Bool_True ? NSUnderlineStyleSingle : NSUnderlineStyleNone);
  }
  if (attributes.strike) {
    attrs[NSStrikethroughStyleAttributeName] = @(attributes.strike == GDOPBAttribute_Bool_True ? NSUnderlineStyleSingle : NSUnderlineStyleNone);
  }

  return attrs;
}

// GDOPBAttribute样式集合转为NSAttribute的属性的字典 针对段落
- (BOOL)parseBlockAttributes:(GDOPBAttribute *)attributes style:(NSMutableParagraphStyle *)paragraph {
  BOOL hasChange = NO;
  GDOPBAttribute_Alignment align = attributes.align;
  if (align != 0) {
    enum NSTextAlignment textAlignment = -1;
    switch (align) {
      case GDOPBAttribute_Alignment_Left:
        textAlignment = NSTextAlignmentLeft;
        break;
      case GDOPBAttribute_Alignment_Center:
        textAlignment = NSTextAlignmentCenter;
        break;
      case GDOPBAttribute_Alignment_Right:
        textAlignment = NSTextAlignmentRight;
        break;
      case GDOPBAttribute_Alignment_Justify:
        textAlignment = NSTextAlignmentJustified;
        break;
      default:
        break;
    }
    if (textAlignment != -1) {
      paragraph.alignment = textAlignment;
      hasChange = YES;
    }
  }
  NSMutableDictionary<NSString *, NSString *> *extras = attributes.extras;

  for (NSString *key in extras) {
    NSString *value = extras[key];
    CGFloat f_value;
    if (![self _value:&f_value fromString:value attributeName:key]) {
      continue;
    }
    if ([key isEqualToString:@"maximumLineHeight"]) {
      paragraph.maximumLineHeight = f_value;
      hasChange = YES;
    } else if ([key isEqualToString:@"minimumLineHeight"]) {
      paragraph.minimumLineHeight = f_value;
      hasChange = YES;
    } else if ([key isEqualToString:@"lineSpacing"]) {
      paragraph.lineSpacing = f_value;
      hasChange = YES;
    } else if ([key isEqualToString:@"paragraphSpacing"]) {
      paragraph.paragraphSpacing = f_value;
      hasChange = YES;
    } else if ([key isEqualToString:@"lineHeightMultiple"]) {
      paragraph.lineHeightMultiple = f_value;
      hasChange = YES;
    } else if ([key isEqualToString:@"paragraphSpacingBefore"]) {
      paragraph.paragraphSpacingBefore = f_value;
      hasChange = YES;
    }
  }
  return hasChange;
}

// NSAttribute的属性的字典转为GDOPBAttribute样式集合
- (GDOPBAttribute *)parseNSAttributes:(NSDictionary<NSString *, id> *)attr {
  GDOPBAttribute *attribute = [GDOPBAttribute message];
  for (NSString *key in attr) {
    if ([key isEqualToString:NSForegroundColorAttributeName]) {
      UIColor *color = attr[key];
      attribute.color = [self _hexFromColor:color];
    } else if ([key isEqualToString:NSBackgroundColorAttributeName]) {
      UIColor *background = attr[key];
      attribute.background = [self _hexFromColor:background];
    } else if ([key isEqualToString:NSFontAttributeName]) {
      UIFont *font = attr[key];
      attribute.size = [self _sizeStringFromNumber:font.pointSize];
      attribute.font = [font.fontName isEqualToString:@"Helvetica"] ? nil : font.fontName;
    } else if ([key isEqualToString:NSLinkAttributeName]) {
      NSURL *url = attr[key];
      attribute.link = url.absoluteString;
    } else if ([key isEqualToString:NSExpansionAttributeName]) {
      attribute.bold = GDOPBAttribute_Bool_True;
    } else if ([key isEqualToString:NSObliquenessAttributeName]) {
      attribute.italic = GDOPBAttribute_Bool_True;
    } else if ([key isEqualToString:NSUnderlineStyleAttributeName]) {
      attribute.underline = GDOPBAttribute_Bool_True;
    } else if ([key isEqualToString:NSStrikethroughStyleAttributeName]) {
      attribute.strike = GDOPBAttribute_Bool_True;
    }
  }
  return attribute;
}

// 更新label和textview的属性和样式
- (void)update {
  if (_label) {
  	_label.attributedText = nil; // force to update
    _label.attributedText = self.attributedText;
  }
  if (_textView) {
  	_textView.attributedText = nil; // force to update
    _textView.attributedText = self.attributedText;
  }
}

// 颜色转换
- (UIColor *)_colorFromHex:(NSString *)hexString {
  unsigned hex;
  NSScanner *scanner = [NSScanner scannerWithString:hexString];
  [scanner setScanLocation:[hexString hasPrefix:@"#"] ? 1 : 0]; // bypass '#' character
  [scanner scanHexInt:&hex];
  return [UIColor colorWithRed:((float) ((hex & 0xFF0000) >> 16)) / 255.0 green:((float) ((hex & 0x00FF00)
      >> 8)) / 255.0      blue:((float) ((hex & 0x0000FF) >> 0)) / 255.0 alpha:1.0];
}

- (NSString *)_hexFromColor:(UIColor *)color {
  const CGFloat *components = CGColorGetComponents(color.CGColor);
  CGFloat r = components[0];
  CGFloat g = components[1];
  CGFloat b = components[2];
  return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
                                    lroundf(r * 255),
                                    lroundf(g * 255),
                                    lroundf(b * 255)];
}

- (BOOL)_value:(CGFloat *)value fromString:(NSString *)string attributeName:(NSString *)attributeName {
  BOOL isValid = NO;
  if ([string hasSuffix:@"px"]) {
    *value = [[string substringToIndex:string.length - @"px".length] floatValue];
    isValid = YES;
  }
  return isValid;
}

- (CGFloat)_sizeFromString:(NSString *)size {
  CGFloat fontSize = 12;
  if ([size hasSuffix:@"px"]) {
    fontSize = [[size substringToIndex:size.length - @"px".length] floatValue];
  }
  return fontSize;
}

- (NSString *)_sizeStringFromNumber:(CGFloat)size {
  if (size == 12) {
    return nil;
  }
  return [NSString stringWithFormat:@"", size, @"px"];
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
  if(!NSEqualRanges(textView.selectedRange, NSMakeRange(0, 0))) {
    textView.selectedRange = NSMakeRange(0, 0);
  }
}

@end
