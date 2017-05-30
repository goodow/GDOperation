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

@interface GDORichTextPlaygroundViewController ()
@property(strong) GDOPBDelta *delta;
@property(strong) GDOPBDelta *contents;
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

  FIRDatabaseReference *ref = [[FIRDatabase database] reference];
  GDOFirebaseAdapter *adapter = [[GDOFirebaseAdapter alloc] initWithRef:[ref child:@"richText/default"]];
  __weak GDORichTextPlaygroundViewController *weak = self;
  adapter.onTextChange = ^(GDOPBDelta *delta, GDOPBDelta *contents) {
      weak.delta = delta;
      weak.contents = contents;
      [weak.tableView reloadData];
  };
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 8;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
  NSUInteger row = indexPath.row;
  switch (row) {
    case 0:
      cell.textLabel.text = @"UITextView 预览:";
      break;
    case 1: {
      UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
      [cell.contentView addSubview:textView];
      textView.translatesAutoresizingMaskIntoConstraints = NO;
      [cell.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
          @"H:|-0-[view]-0-|"                                                  options:0 metrics:nil views:@{@"view" : textView}]];
      [cell.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
          @"V:|-0-[view(100)]|"                                                      options:0 metrics:nil views:@{@"view" : textView}]];
      GDORichText *richText = [[GDORichText alloc] initWithTextView:textView];
      richText.setContents(self.contents);

      [cell layoutIfNeeded];
    }
      break;
    case 2:
      cell.textLabel.text = @"UILabel 预览:";
      break;
    case 3: {
      GDORichText *richText = [[GDORichText alloc] initWithLabel:cell.textLabel];
      richText.setContents(self.contents);
      cell.textLabel.numberOfLines = 0;
    }
      break;
    case 4:
      cell.textLabel.text = @"差量:";
      break;
    case 5:
      cell.textLabel.numberOfLines = 0;
      cell.textLabel.text = self.delta.toJson.description;
      break;
    case 6:
      cell.textLabel.text = @"文档:";
      break;
    case 7:
      cell.textLabel.numberOfLines = 0;
      cell.textLabel.text = self.contents.toJson.description;
      break;
    default:
      break;
  }

  [cell setNeedsUpdateConstraints];
  [cell updateConstraintsIfNeeded];
  return cell;
}

@end