//
// Created by Larry Tin on 2016/12/10.
//

#import "GDORichText.h"
#import "NSObject+GDChannel.h"
#import "GDOEditor.h"
#import "GDOLabel.h"
#import "GDOTextView.h"

@interface GDORichText ()
@property (nonatomic, strong) id<GDOEditor> editor;
@end

@implementation GDORichText {
}

- (instancetype)initWithLabel:(UILabel *)label {
  self = GDOLabel.attachView(label);
  return self;
}

- (instancetype)initWithTextView:(UITextView *)textView {
  self = GDOTextView.attachView(textView);
  return self;
}

- (instancetype)initWithEditor:(id<GDOEditor>)editor {
  self = [super init];
  if (self) {
    _editor = editor;
  }

  return self;
}

#pragma mark - Content

// 更新content
- (GDOPBDelta *(^)(GDOPBDelta *delta))updateContents {
  return ^GDOPBDelta *(GDOPBDelta *delta) {
      return self.editor.applyDelta(delta);
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
      unsigned long long int length = self.editor.delta.length;
      if (length) {
        delta = GDOPBDelta.message.delete(length).compose(delta);
      }
      return self.updateContents(delta);
  };
}

// 获取文本
- (NSString *(^)(NSRange range))getText {
  return ^NSString *(NSRange range) {
      return nil;
  };
}

// 设置文本
- (GDOPBDelta *(^)(NSString *text))setText {
  return ^GDOPBDelta *(NSString *text) {
      return [GDOPBDelta message].insert(text, nil).delete(self.editor.delta.length);
  };
}

// 删除文本
- (GDOPBDelta *(^)(NSRange range))deleteText {
  return ^GDOPBDelta *(NSRange range) {
      return [GDOPBDelta message].retain_p(range.location, nil).delete(range.length);
  };
}

// 插入文本
- (GDOPBDelta *(^)(unsigned long long index, NSString *text, GDOPBAttribute *attributes))insertText {
  return ^GDOPBDelta *(unsigned long long int index, NSString *text, GDOPBAttribute *attributes) {
      return [GDOPBDelta message].retain_p(index, nil).insert(text, attributes);
  };
}

// 获取AttributedString长度
- (unsigned long long (^)())getLength {
  return ^unsigned long long int {
      return self.editor.delta.length ?: 1;
  };
}

#pragma mark - Formatting

// 获取range范围内的样式,取出来的是NSDictionary，需要转为GDOPBAttribute
- (GDOPBAttribute *(^)(NSRange range))getFormat {
  return ^GDOPBAttribute *(NSRange range) {
//      NSRange r;
//      NSDictionary<NSString *, id> *attr = [self.attributedText attributesAtIndex:range.location effectiveRange:&r];
//      if (r.length != range.length) {
//        return [self parseNSAttributes:attr];
//      }
      return NULL;
  };
}

- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatText {
  return ^GDOPBDelta *(NSRange range, GDOPBAttribute *attributes) {
//      NSDictionary<NSString *, id> *attr = [self parseInlineAttributes:attributes];
//      [self.attributedText addAttributes:attr range:range];
//      [self update];
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

@end