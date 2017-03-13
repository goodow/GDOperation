//
// Created by Larry Tin on 2016/12/10.
//

#import "GDORichText.h"
#import <UIKit/NSAttributedString.h>
#import <UIKit/NSParagraphStyle.h>
#import "NSObject+GDChannel.h"
#import "GDCBusProvider.h"
#import "UITextView+GDORichText.h"

@interface GDORichText () <UITextViewDelegate>
@property(nonatomic, readonly) NSMutableAttributedString *attributedText;
@property(nonatomic, weak) UILabel *label;
@property(nonatomic, weak) UITextView *textView;
@end

@implementation GDORichText {
}

- (instancetype)initWithLabel:(UILabel *)label {
  self = [super init];
  if (self) {
    _label = label;
    _attributedText = label.attributedText.mutableCopy;
    if (!_attributedText.length) {
      self.setText(@"\n");
    }
  }

  return self;
}

- (instancetype)initWithTextView:(UITextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _textView.delegate = self;
    _textView.richText = self;
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

- (GDOPBDelta *(^)(GDOPBDelta *delta))updateContents {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
      [self apply:delta];
      [self update];
      return nil;
  };
}

- (GDOPBDelta *(^)(NSRange range))getContents {
  return ^GDOPBDelta *(NSRange range) {
      return nil;
  };
}

- (GDOPBDelta *(^)(GDOPBDelta *delta))setContents {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
      NSUInteger length = self.attributedText.length;
      [self.attributedText deleteCharactersInRange:NSMakeRange(0, length)];
      GDOPBDelta *contents = self.updateContents(delta);
//      return contents.delete(length);
      return nil;
  };
}

- (NSString *(^)(NSRange range))getText {
  return ^NSString *(NSRange range) {
      NSString *string = self.attributedText.string;
      return string.length ? string : @"\n";
  };
}

- (GDOPBDelta *(^)(NSString *text))setText {
  return ^GDOPBDelta *(NSString *text) {
      NSUInteger length = self.attributedText.length;
      [self.attributedText replaceCharactersInRange:NSMakeRange(0, length) withString:text];
      [self update];
      return [GDOPBDelta message].insert(text, nil).delete(length);
  };
}

- (GDOPBDelta *(^)(NSRange range))deleteText {
  return ^GDOPBDelta *(NSRange range) {
      [self.attributedText deleteCharactersInRange:range];
      [self update];
      return [GDOPBDelta message].retain_p(range.location, nil).delete(range.length);
  };
}

- (GDOPBDelta *(^)(unsigned long long index, NSString *text, GDOPBAttribute *attributes))insertText {
  return ^GDOPBDelta *(unsigned long long int index, NSString *text, GDOPBAttribute *attributes) {
      NSAttributedString *string = [[NSAttributedString alloc] initWithString:text attributes:[self parseInlineAttributes:attributes]];
      [self.attributedText insertAttributedString:string atIndex:index];
      [self update];
      return [GDOPBDelta message].retain_p(index, nil).insert(text, attributes);
  };
}

- (unsigned long long (^)())getLength {
  return ^unsigned long long int {
      return self.attributedText.length ?: 1;
  };
}

#pragma mark - Formatting

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

- (void)apply:(GDOPBDelta *)delta {
  long cursor = 0;
  for (GDOPBDelta_Operation *op in delta.opsArray) {
    if (op.insert.length) {
      NSString *text = op.insert;
      if (![text isEqualToString:@"\n"]) {
        NSDictionary *attr = [self parseInlineAttributes:op.attributes];
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:attr];
        [self.attributedText insertAttributedString:str atIndex:cursor];
        if (op.attributes.link.length) {
          _textView.linkTextAttributes = attr;
        }
      } else {
        NSRange range = [self.attributedText.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, cursor)];
        long lineStart = 0;
        if (range.location != NSNotFound) {
          lineStart = range.location + 1;
        }
        NSMutableParagraphStyle *paragraphStyle;
        if (cursor) {
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
        float spacing = op.attributes.width.floatValue; // 间隔
        if (spacing > 0) {
          unichar objectReplacementChar = 0xFFFC;
          NSAttributedString * placeholder = [[NSAttributedString alloc] initWithString:[NSString stringWithCharacters:&objectReplacementChar length:1] attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:.1]}]; // iOS 9如果设置font-size为0，则spacing不生效
          [self.attributedText insertAttributedString:placeholder atIndex:cursor];
          [self.attributedText addAttribute:NSKernAttributeName
                                      value:@(spacing - 0.1)
                                      range:NSMakeRange(cursor, 1)];
          cursor += 1;
        }
        
      } else {
        // other implementation
//        cursor += 1;
      }
      continue;
    }
  }
}

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

-(GDOPBAttribute *)parseNSAttributes:(NSDictionary<NSString *, id> *)attr {
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

- (void)update {
  if (_label) {
    _label.attributedText = self.attributedText;
  }
  if (_textView) {
    _textView.attributedText = self.attributedText;
  }
}

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
  BOOL isValid;
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
- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange {
  NSString *clientId = [GDCBusProvider clientId];
  NSString *topic = [NSString stringWithFormat:@"%@/action/views", clientId];
  [self.bus publishLocal:topic payload:URL.absoluteString];
  return NO;
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  // 该方法禁止textView被select时的高亮（因为[textView:shouldInteractWithURL:inRange:]方法必须在textView是selectable时生效）
  if(!NSEqualRanges(textView.selectedRange, NSMakeRange(0, 0))) {
    textView.selectedRange = NSMakeRange(0, 0);
  }
}

@end
