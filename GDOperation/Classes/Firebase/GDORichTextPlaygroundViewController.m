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
@property(nonatomic, strong) GDOFirebaseAdapter *adapter;
@property(nonatomic, strong) UIView *textView;
@property(nonatomic, strong) GDORichText *richText;
@property(nonatomic, strong) NSLayoutConstraint *heightConstraint;
@end

enum EditorType {
  UI_Label, UI_TextView, YY_TextView
};
@implementation GDORichTextPlaygroundViewController

- (id)initWithFile:(NSString *)urlString specifier:(id)specifier {
  if (self = [super init]) {
    self.title = @"富文本预览";
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.tableView.estimatedRowHeight = 44;
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.allowsSelection = NO;

  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"YYTextView" style:UIBarButtonItemStylePlain target:self action:@selector(switchEditor)];
  [self reloadEditor:YY_TextView title:@"YYTextView"];

  FIRDatabaseReference *ref = FIRDatabase.database.reference;
  self.adapter = [[GDOFirebaseAdapter alloc] initWithRef:[ref child:@"richText/default"]];
  __weak GDORichTextPlaygroundViewController *weak = self;
  self.adapter.onTextChange = ^(GDOPBDelta *delta, GDOPBDelta *contents) {
      weak.delta = delta;
      weak.contents = contents;

      if (weak.richText) { // UILabel 实现没有保存 richText
        weak.richText.updateContents(delta);
      }
      [weak.tableView reloadData];
  };
}

- (void)reloadEditor:(enum EditorType)type title:(NSString *)title {
  self.navigationItem.rightBarButtonItem.title = title;
  switch (type) {
    case UI_TextView: {
      UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
      textView.translatesAutoresizingMaskIntoConstraints = NO;
      textView.editable = NO;
      self.richText = GDOTextView.attachView(textView);
      self.textView = textView;
      break;
    }
    case YY_TextView:
      [self createYYTextView];
      break;
    case UI_Label:
      self.richText = nil;
      self.textView = nil;
      break;
  }

  if (self.richText) {
    self.richText.setContents(self.contents);
  }
  [self.tableView reloadData];
}

- (void)createYYTextView {
  YYTextView *yyTextView = [[YYTextView alloc] initWithFrame:CGRectZero];
  yyTextView.translatesAutoresizingMaskIntoConstraints = NO;
  yyTextView.editable = NO;
  self.richText = GDOYYTextView.attachView(yyTextView);
  self.textView = yyTextView;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 6;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
  NSUInteger row = indexPath.row;
  switch (row) {
    case 0:
      cell.textLabel.text = @"预览:";
      break;
    case 1: {
      NSString *editor = self.navigationItem.rightBarButtonItem.title;
      if ([editor isEqualToString:@"UILabel"]) {
        GDOLabel.attachView(cell.textLabel).setContents(self.contents);
        cell.textLabel.numberOfLines = 0;
        break;
      }

//      cell = [tableView dequeueReusableCellWithIdentifier:editor];
//      if (!cell) {
//        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:editor];
        [cell.contentView addSubview:self.textView];
        [cell.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
            @"H:|-0-[view]-0-|"                                                  options:0 metrics:nil views:@{@"view": self.textView}]];
        [cell.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
            @"V:|-0-[view]-0@750-|"                                              options:0 metrics:nil views:@{@"view": self.textView}]];
        self.heightConstraint = [NSLayoutConstraint constraintWithItem:self.textView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44];
        [self.textView addConstraint:self.heightConstraint];
//      }
      CGSize size = [self.textView sizeThatFits:CGSizeMake(cell.bounds.size.width, MAXFLOAT)];
      self.heightConstraint.constant = size.height;
      //      [cell layoutIfNeeded];
      break;
    }
    case 2:
      cell.textLabel.text = @"差量:";
      break;
    case 3:
      cell.textLabel.numberOfLines = 0;
      cell.textLabel.text = [GDORichTextPlaygroundViewController prettyPrintJson:self.delta.toJson];
      cell.textLabel.font = [cell.textLabel.font fontWithSize:10];
      break;
    case 4:
      cell.textLabel.text = @"文档:";
      break;
    case 5:
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

- (void)switchEditor {
  __weak GDORichTextPlaygroundViewController *weak = self;
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"切换编辑器实现" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
  UIAlertAction *labelAction = [UIAlertAction actionWithTitle:@"UILabel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
      [weak reloadEditor:UI_Label title:action.title];
  }];
  [alertController addAction:labelAction];
  UIAlertAction *textViewAction = [UIAlertAction actionWithTitle:@"UITextView" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
      [weak reloadEditor:UI_TextView title:action.title];
  }];
  [alertController addAction:textViewAction];
  UIAlertAction *yyTextAction = [UIAlertAction actionWithTitle:@"YYTextView" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
      [weak reloadEditor:YY_TextView title:action.title];
  }];
  [alertController addAction:yyTextAction];
  [self presentViewController:alertController animated:YES completion:nil];
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
