//
// Created by Larry Tin on 2016/12/10.
//

#import "GDORichText.h"
#import <UIKit/NSAttributedString.h>
#import <UIKit/NSParagraphStyle.h>

@interface GDORichText ()
@property(nonatomic, readonly) NSMutableAttributedString *attributedText;
@end

@implementation GDORichText {
  UILabel *_label;
}
- (instancetype)initWithLabel:(UILabel *)label {
  self = [super init];
  if (self) {
    _label = label;
    _attributedText = label.attributedText.mutableCopy;
  }

  return self;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _attributedText = [[NSMutableAttributedString alloc] init];
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
      [self.attributedText deleteCharactersInRange:NSMakeRange(0, self.attributedText.length)];
      return self.updateContents(delta);
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
      text = [text hasSuffix:@"\n"] ? text : [text stringByAppendingString:@"\n"];
      [self.attributedText replaceCharactersInRange:NSMakeRange(0, self.attributedText.length) withString:text];
      [self update];
      return nil;
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
      return NULL;
  };
}

- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatText {
  return ^GDOPBDelta *(NSRange range, GDOPBAttribute *attributes) {
      return nil;
  };
}

- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatLine {
  return ^GDOPBDelta *(NSRange range, GDOPBAttribute *attributes) {
      return nil;
  };
}

- (GDOPBDelta *(^)(NSRange range))removeFormat {
  return ^GDOPBDelta *(NSRange range) {
      return nil;
  };
}

#pragma mark - Internal methods

- (void)apply:(GDOPBDelta *)delta {
  long cursor = 0;
  for (GDOPBOperation *op in delta.opsArray) {
    if (op.insert.length) {
      NSString *text = op.insert;
      if (![text isEqualToString:@"\n"]) {
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:[self parseInlineAttributes:op.attributes]];
        [self.attributedText insertAttributedString:str atIndex:cursor];
      } else {
        NSRange range = [self.attributedText.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, cursor)];
        long lineStart = 0;
        if (range.location != NSNotFound) {
          lineStart = range.location + 1;
        }
        NSMutableParagraphStyle *paragraphStyle = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:lineStart longestEffectiveRange:nil inRange:NSMakeRange(lineStart, 1)];
        [self.attributedText insertAttributedString:[[NSAttributedString alloc] initWithString:text attributes:paragraphStyle] atIndex:cursor];
        if ([self parseBlockAttributes:op.attributes style:paragraphStyle ? paragraphStyle.mutableCopy : [[NSMutableParagraphStyle alloc] init]]) {
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
      cursor += 1;
      continue;
    }
  }
}


- (NSDictionary<NSString *, id> *)parseInlineAttributes:(GDOPBAttribute *)attributes {
  NSMutableDictionary<NSString *, id> *attrs = @{}.mutableCopy;
  if (attributes.color.length) {
    attrs[NSForegroundColorAttributeName] = [self _getColor:attributes.color];
  }
  if (attributes.background.length) {
    attrs[NSBackgroundColorAttributeName] = [self _getColor:attributes.background];
  }
  if (attributes.size.length || attributes.font.length) {
//    UIFont *font = [self.attributedText attribute:NSFontAttributeName atIndex:<#(NSUInteger)location#> effectiveRange:nil];
    UIFont *font = [UIFont fontWithName:attributes.font.length ? attributes.font : @"Helvetica" size:[self _getSize:attributes.size]];
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
    attrs[NSUnderlineStyleAttributeName] = @(attributes.strike == GDOPBAttribute_Bool_True ? NSUnderlineStyleSingle : NSUnderlineStyleNone);
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
    if ([key isEqualToString:@"maximumLineHeight"]) {
      paragraph.maximumLineHeight = [self _getSize:value];
      hasChange = YES;
    } else if ([key isEqualToString:@"minimumLineHeight"]) {
      paragraph.minimumLineHeight = [self _getSize:value];
      hasChange = YES;
    } else if ([key isEqualToString:@"lineSpacing"]) {
      paragraph.lineSpacing = [self _getSize:value];
      hasChange = YES;
    } else if ([key isEqualToString:@"paragraphSpacing"]) {
      paragraph.paragraphSpacing = [self _getSize:value];
      hasChange = YES;
    } else if ([key isEqualToString:@"lineHeightMultiple"]) {
      paragraph.lineHeightMultiple = [self _getSize:value];
      hasChange = YES;
    } else if ([key isEqualToString:@"paragraphSpacingBefore"]) {
      paragraph.paragraphSpacingBefore = [self _getSize:value];
      hasChange = YES;
    }
  }
  return hasChange;
}

- (void)update {
  if (_label) {
    _label.attributedText = self.attributedText;
  }
}

- (UIColor *)_getColor:(NSString *)hexString {
  unsigned hex;
  NSScanner *scanner = [NSScanner scannerWithString:hexString];
  [scanner setScanLocation:[hexString hasPrefix:@"#"] ? 1 : 0]; // bypass '#' character
  [scanner scanHexInt:&hex];
  return [UIColor colorWithRed:((float) ((hex & 0xFF0000) >> 16)) / 255.0 green:((float) ((hex & 0x00FF00)
      >> 8)) / 255.0      blue:((float) ((hex & 0x0000FF) >> 0)) / 255.0 alpha:1.0];
}

- (CGFloat)_getSize:(NSString *)size {
  CGFloat fontSize = 12;
  if ([size hasSuffix:@"px"]) {
    fontSize = [[size substringToIndex:size.length - @"px".length] floatValue];
  }
  return fontSize;
}
@end