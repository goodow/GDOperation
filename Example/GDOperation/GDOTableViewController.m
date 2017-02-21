//
//  GDOTableViewController.m
//  GDOperation
//
//  Created by Larry Tin on 2016/12/10.
//  Copyright © 2016年 Larry Tin. All rights reserved.
//

#import "GDOTableViewController.h"
#import "GDOTableViewCell.h"
#import "GDOModel.h"
#import "NSObject+GDChannel.h"
#import "GDOTextViewTableViewCell.h"

@interface GDOTableViewController ()
@property (strong, nonatomic) GDOModel *model;
@end

@implementation GDOTableViewController


- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    self.model = [[GDOModel alloc] init];
  }

  return self;
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.tableView.allowsSelection = NO;
  [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass(GDOTableViewCell.class) bundle:nil] forCellReuseIdentifier:NSStringFromClass(GDOTableViewCell.class)];
  [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass(GDOTextViewTableViewCell.class) bundle:nil] forCellReuseIdentifier:NSStringFromClass(GDOTextViewTableViewCell.class)];

  // Self-sizing table view cells in iOS 8 require that the rowHeight property of the table view be set to the constant UITableViewAutomaticDimension
  self.tableView.rowHeight = UITableViewAutomaticDimension;

  // Self-sizing table view cells in iOS 8 are enabled when the estimatedRowHeight property of the table view is set to a non-zero value.
  // Setting the estimated row height prevents the table view from calling tableView:heightForRowAtIndexPath: for every row in the table on first load;
  // it will only be called as cells are about to scroll onscreen. This is a major performance optimization.
  self.tableView.estimatedRowHeight = 44.0; // set this to whatever your "average" cell height is; it doesn't need to be very accurate
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [self.model.dataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell <GDOTableViewCellProtocol> *cell;
  if (indexPath.row == 0) {
    cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(GDOTableViewCell.class) forIndexPath:indexPath];
  } else {
    cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(GDOTextViewTableViewCell.class) forIndexPath:indexPath];
  }

  // Configure the cell for this indexPath
  [cell applyPatch:self.model.dataSource[indexPath.row]];

  // Make sure the constraints have been added to this cell, since it may have just been created from scratch
  [cell setNeedsUpdateConstraints];
  [cell updateConstraintsIfNeeded];

  return cell;
}

@end
