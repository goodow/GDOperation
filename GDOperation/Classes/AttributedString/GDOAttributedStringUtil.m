//
// Created by Larry Tin on 2017/5/31.
//

#import "GDOAttributedStringUtil.h"
#import "GoodowOperation.pbobjc.h"
#import "GDOPBDelta+GDOperation.h"


@implementation GDOAttributedStringUtil {

}

// GDOPBAttribute样式集合转为NSAttribute的属性的字典 针对单个文字
+ (NSDictionary<NSString *, id> *)parseInlineAttributes:(GDOPBAttribute *)attributes toRemove:(NSArray **)toRemovePtr {
  NSMutableArray *toRemove = nil;
  if (toRemovePtr) {
    toRemove = @[].mutableCopy;
    *toRemovePtr = toRemove;
  }
  BOOL (^hasStringValue)(NSString *, NSString *) = ^(NSString *key, NSString *value) {
      if (!value.length) {
        return NO;
      }
      if (toRemove && [NULL_SENTINEL_CHARACTER isEqualToString:value]) {
        if (key) { [toRemove addObject:key]; }
        return NO;
      }
      return YES;
  };
  BOOL (^hasBoolValue)(NSString *, GDOPBAttribute_Bool) = ^(NSString *key, GDOPBAttribute_Bool value) {
      if (value == 0) {
        return NO;
      }
      if (toRemove && value == GDOPBAttribute_Bool_False) {
        if (key) { [toRemove addObject:key]; }
        return NO;
      }
      return YES;
  };

  NSMutableDictionary<NSString *, id> *attrs = @{}.mutableCopy;
  if (hasStringValue(NSForegroundColorAttributeName, attributes.color)) {
    attrs[NSForegroundColorAttributeName] = [self _colorFromHex:attributes.color];
  }
  if (hasStringValue(NSBackgroundColorAttributeName, attributes.background)) {
    attrs[NSBackgroundColorAttributeName] = [self _colorFromHex:attributes.background];
  }
  if (hasStringValue(nil, attributes.size) || hasStringValue(nil, attributes.font)) {
    //    UIFont *font = [self.attributedText attribute:NSFontAttributeName atIndex:<#(NSUInteger)location#> effectiveRange:nil];
    UIFont *font = [UIFont fontWithName:hasStringValue(nil, attributes.font) ? attributes.font : @"Helvetica" size:[self sizeFromString:attributes.size]];
    attrs[NSFontAttributeName] = font;
  }
  if (hasStringValue(NSLinkAttributeName, attributes.link)) {
    attrs[NSLinkAttributeName] = attributes.link;
  }
  if (hasBoolValue(NSExpansionAttributeName, attributes.bold)) {
    attrs[NSExpansionAttributeName] = @0.2;
  }
  if (hasBoolValue(NSObliquenessAttributeName, attributes.italic)) {
    attrs[NSObliquenessAttributeName] = @0.3;
  }
  if (hasBoolValue(NSUnderlineStyleAttributeName, attributes.underline)) {
    attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
  }
  if (hasBoolValue(NSStrikethroughStyleAttributeName, attributes.strike)) {
    attrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
  }

  return attrs;
}

// GDOPBAttribute样式集合转为NSAttribute的属性的字典 针对段落
+ (BOOL)parseBlockAttributes:(GDOPBAttribute *)attributes style:(NSMutableParagraphStyle *)paragraph {
  BOOL hasChange = NO;
  GDOPBAttribute_Alignment align = GDOPBAttribute_Align_RawValue(attributes);
  if (align != 0) {
    enum NSTextAlignment textAlignment = -1;
    switch (align) {
      case GDOPBAttribute_Alignment_Left:
      case NULL_ENUM_VALUE:
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
+ (GDOPBAttribute *)parseNSAttributes:(NSDictionary<NSString *, id> *)attr {
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

// 颜色转换
+ (UIColor *)_colorFromHex:(NSString *)hexString {
  unsigned hex;
  NSScanner *scanner = [NSScanner scannerWithString:hexString];
  [scanner setScanLocation:[hexString hasPrefix:@"#"] ? 1 : 0]; // bypass '#' character
  [scanner scanHexInt:&hex];
  return [UIColor colorWithRed:((float) ((hex & 0xFF0000) >> 16)) / 255.0 green:((float) ((hex & 0x00FF00)
      >> 8)) / 255.0      blue:((float) ((hex & 0x0000FF) >> 0)) / 255.0 alpha:1.0];
}

+ (NSString *)_hexFromColor:(UIColor *)color {
  const CGFloat *components = CGColorGetComponents(color.CGColor);
  CGFloat r = components[0];
  CGFloat g = components[1];
  CGFloat b = components[2];
  return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
                                    lroundf(r * 255),
                                    lroundf(g * 255),
                                    lroundf(b * 255)];
}

+ (BOOL)_value:(CGFloat *)value fromString:(NSString *)string attributeName:(NSString *)attributeName {
  BOOL isValid = NO;
  if ([string hasSuffix:@"px"]) {
    *value = [[string substringToIndex:string.length - @"px".length] floatValue];
    isValid = YES;
  }
  return isValid;
}

+ (CGFloat)sizeFromString:(NSString *)size {
  CGFloat fontSize = 12;
  if ([size hasSuffix:@"px"]) {
    fontSize = [[size substringToIndex:size.length - @"px".length] floatValue];
  }
  return fontSize;
}

+ (NSString *)_sizeStringFromNumber:(CGFloat)size {
  if (size == 12) {
    return nil;
  }
  return [NSString stringWithFormat:@"%f%@", size, @"px"];
}
@end