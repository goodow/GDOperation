//
// Created by Larry Tin on 12/11/16.
//

#import <Foundation/Foundation.h>
#import "GoodowBool.pbobjc.h"
#import "GoodowOperation.pbobjc.h"

@interface GDOPBAttribute (FluentInterface)

- (GDOPBAttribute *(^)(NSString *color))setColor;
- (GDOPBAttribute *(^)(NSString *background))setBackground;
- (GDOPBAttribute *(^)(NSString *size))setSize;
- (GDOPBAttribute *(^)(NSString *font))setFont;
- (GDOPBAttribute *(^)(NSString *link))setLink;
- (GDOPBAttribute *(^)(enum GDPBBool bold))setBold;
- (GDOPBAttribute *(^)(enum GDPBBool italic))setItalic;
- (GDOPBAttribute *(^)(enum GDPBBool underline))setUnderline;
- (GDOPBAttribute *(^)(enum GDPBBool strike))setStrike;
- (GDOPBAttribute *(^)(enum GDPBBool code))setCode;
- (GDOPBAttribute *(^)(enum GDOPBScript script))setScript;

- (GDOPBAttribute *(^)(NSMutableDictionary<NSString*, NSString*> *extras))setExtras;

- (GDOPBAttribute *(^)(enum GDOPBAlignment align))setAlign;

- (GDOPBAttribute *(^)(NSString *width))setWidth;
- (GDOPBAttribute *(^)(NSString *htight))setHeight;

@end