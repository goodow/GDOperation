//
// Created by Larry Tin on 2017/5/31.
//

#import <Foundation/Foundation.h>
#import "GDOEditor.h"
#import "YYTextView.h"

@interface GDOYYTextView : NSObject <GDOEditor>

+ (GDORichText *(^)(YYTextView *textView))attachView;

@end
