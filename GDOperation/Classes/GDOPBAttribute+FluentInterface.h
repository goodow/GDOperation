//
// Created by Larry Tin on 12/11/16.
//

#import <Foundation/Foundation.h>
#import "GoodowOperation.pbobjc.h"

@interface GDOPBAttribute (FluentInterface)

- (GDOPBAttribute *(^)(NSString *color))setColor;
- (GDOPBAttribute *(^)(NSString *background))setBackground;
- (GDOPBAttribute *(^)(NSString *size))setSize;
- (GDOPBAttribute *(^)(NSString *font))setFont;
- (GDOPBAttribute *(^)(NSString *link))setLink;
- (GDOPBAttribute *(^)(enum GDOPBAttribute_Bool bold))setBold;
- (GDOPBAttribute *(^)(enum GDOPBAttribute_Bool italic))setItalic;
- (GDOPBAttribute *(^)(enum GDOPBAttribute_Bool underline))setUnderline;
- (GDOPBAttribute *(^)(enum GDOPBAttribute_Bool strike))setStrike;
- (GDOPBAttribute *(^)(enum GDOPBAttribute_Bool code))setCode;
- (GDOPBAttribute *(^)(enum GDOPBAttribute_Script script))setScript;

- (GDOPBAttribute *(^)(NSMutableDictionary<NSString*, NSString*> *extras))setExtras;

- (GDOPBAttribute *(^)(enum GDOPBAttribute_Alignment align))setAlign;

- (GDOPBAttribute *(^)(NSString *width))setWidth;
- (GDOPBAttribute *(^)(NSString *htight))setHeight;

@end