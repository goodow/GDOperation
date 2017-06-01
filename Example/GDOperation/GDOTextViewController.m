//
//  GDOViewController.m
//  GDOperation
//
//  Created by Larry Tin on 12/10/2016.
//  Copyright (c) 2016 Larry Tin. All rights reserved.
//

#import "GDOTextViewController.h"
#import "GDOModel.h"
#import "GoodowOperation.pbobjc.h"
#import "GDOPBDelta+GDOperation.h"
#import "GPBMessage+JsonFormat.h"
#import "GDORichText.h"
#import "GDORichTextPlaygroundViewController.h"

@interface GDOTextViewController ()
@property(strong ,nonatomic)UITextView *detailTextView;
@end

@implementation GDOTextViewController

- (void)viewDidLoad
{
    [super viewDidLoad];


}
-(void)viewDidAppear:(BOOL)animated{


}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(IBAction)TextTest:(id)sender{
  [self.navigationController pushViewController:[[GDORichTextPlaygroundViewController alloc] initWithStyle:UITableViewStylePlain] animated:YES];
}


@end
