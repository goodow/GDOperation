//
//  UITextView+GDORichText.m
//  Pods
//
//  Created by alonsolu on 2017/2/21.
//
//

#import "UITextView+GDORichText.h"
#import <objc/runtime.h>
#import "GDORichText.h"

static const char kRichTextKey = 0;

@implementation UITextView (GDORichText)
@dynamic richText;

- (void)setRichText:(GDORichText *)richText {
  objc_setAssociatedObject(self, &kRichTextKey, richText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (GDORichText *)richText {
  return objc_getAssociatedObject(self, &kRichTextKey);
}
@end
