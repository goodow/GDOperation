//
//  QQLRichTextPlaygroundViewController.m
//  QQLiveBroadcast
//
//  Created by Larry Tin on 2017/5/30.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "GDORichTextPlaygroundViewController.h"
#import "GDORichText.h"
#import "GDOFirebaseAdapter.h"
#import "GPBMessage+JsonFormat.h"
#import "Firebase.h"
#import "GDOTextView.h"
#import "GDOLabel.h"
#import "YYTextView.h"
#import "GDOYYTextView.h"

@interface GDORichTextPlaygroundViewController ()
@property(strong) GDOPBDelta *delta;
@property(strong) GDOPBDelta *contents;
@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, strong) GDORichText *richText;
@property(nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property(nonatomic, strong) YYTextView *yytextView;
@property(nonatomic, strong) GDORichText *yyrichText;
@property(nonatomic, strong) NSLayoutConstraint *yyheightConstraint;
@end

@implementation GDORichTextPlaygroundViewController

- (id)initWithFile:(NSString *)urlString specifier:(id)specifier {
  if (self = [super init]) {
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.tableView.estimatedRowHeight = 44;
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.allowsSelection = NO;

  self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
  self.textView.translatesAutoresizingMaskIntoConstraints = NO;
  self.textView.editable = NO;
  self.richText = GDOTextView.attachView(self.textView);

  self.yytextView = [[YYTextView alloc] initWithFrame:CGRectZero];
  self.yytextView.translatesAutoresizingMaskIntoConstraints = NO;
  self.yytextView.editable = NO;
  self.yyrichText = GDOYYTextView.attachView(self.yytextView);

  NSString *dataFile = [[NSBundle mainBundle] pathForResource:@"richtext" ofType:@"json"];
  NSData *dataj = [NSData dataWithContentsOfFile:dataFile];//[dataFile dataUsingEncoding:NSUTF8StringEncoding];

  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:dataj
                                                       options:NSJSONReadingMutableContainers
                                                         error:nil];

  self.yyrichText.updateContents([GDOPBDelta parseFromJson:json error:nil]);
  self.richText.updateContents([GDOPBDelta parseFromJson:json error:nil]);

  FIRDatabaseReference *ref = [[FIRDatabase database] reference];
  GDOFirebaseAdapter *adapter = [[GDOFirebaseAdapter alloc] initWithRef:[ref child:@"richText/default"]];
  __weak GDORichTextPlaygroundViewController *weak = self;
  adapter.onTextChange = ^(GDOPBDelta *delta, GDOPBDelta *contents) {
      weak.delta = delta;
      weak.contents = contents;

//      weak.richText.updateContents(delta);
//      weak.yyrichText.updateContents(delta);
      [weak.tableView reloadData];
  };
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
  NSUInteger row = indexPath.row;
  switch (row) {
    case 0:
      cell.textLabel.text = @"UITextView 预览:";
      break;
    case 1: {
      cell = [tableView dequeueReusableCellWithIdentifier:@"textView"];
      if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"textView"];
        [cell.contentView addSubview:self.textView];
        [cell.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
            @"H:|-0-[view]-0-|"                                                  options:0 metrics:nil views:@{@"view": self.textView}]];
        [cell.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
            @"V:|-0-[view]-0@750-|"                                              options:0 metrics:nil views:@{@"view": self.textView}]];
        self.heightConstraint = [NSLayoutConstraint constraintWithItem:self.textView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44];
        [self.textView addConstraint:self.heightConstraint];
      }

      CGSize size = [self.textView sizeThatFits:CGSizeMake(cell.bounds.size.width, MAXFLOAT)];
      self.heightConstraint.constant = size.height;
      //      [cell layoutIfNeeded];
    }
      break;
    case 2:
      cell.textLabel.text = @"YYTextView 预览:";
      break;
    case 3:{
      cell = [tableView dequeueReusableCellWithIdentifier:@"yytextView"];
      if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"yytextView"];
        [cell.contentView addSubview:self.yytextView];
        [cell.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                                          @"H:|-0-[view]-0-|"                                                  options:0 metrics:nil views:@{@"view" : self.yytextView}]];
        [cell.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                                          @"V:|-0-[view]-0@750-|"                                                      options:0 metrics:nil views:@{@"view" : self.yytextView}]];
        self.yyheightConstraint = [NSLayoutConstraint constraintWithItem:self.yytextView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44];
        [self.yytextView addConstraint:self.yyheightConstraint];
      }

      CGSize size = [self.yytextView sizeThatFits:CGSizeMake(cell.bounds.size.width, MAXFLOAT)];
      self.yyheightConstraint.constant = size.height;
      //      [cell layoutIfNeeded];
    }
      break;
    case 4:
      cell.textLabel.text = @"UILabel 预览:";
      break;
    case 5:
      GDOLabel.attachView(cell.textLabel).setContents(self.contents);
      cell.textLabel.numberOfLines = 0;
      break;
    case 6:
      cell.textLabel.text = @"差量:";
      break;
    case 7:
      cell.textLabel.numberOfLines = 0;
      cell.textLabel.text = [GDORichTextPlaygroundViewController prettyPrintJson:self.delta.toJson];
      cell.textLabel.font = [cell.textLabel.font fontWithSize:10];
      break;
    case 8:
      cell.textLabel.text = @"文档:";
      break;
    case 9:
      cell.textLabel.numberOfLines = 0;
      cell.textLabel.text = [GDORichTextPlaygroundViewController prettyPrintJson:self.contents.toJson];
      cell.textLabel.font = [cell.textLabel.font fontWithSize:10];
      break;
    default:
      break;
  }

  [cell setNeedsUpdateConstraints];
  [cell updateConstraintsIfNeeded];
  return cell;
}

+ (NSString *)prettyPrintJson:(id)jsonObject {
  if (!jsonObject) {
    return nil;
  }
  NSError *error = nil;
  NSData *prettyJsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:NSJSONWritingPrettyPrinted error:&error];
  return error ? error.description : [[NSString alloc] initWithData:prettyJsonData encoding:NSUTF8StringEncoding];
//  return [NSString stringWithUTF8String:prettyJsonData.bytes];
}

@end
