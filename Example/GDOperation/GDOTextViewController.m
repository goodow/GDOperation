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

  self.detailTextView = [[UITextView alloc] initWithFrame:self.view.frame];
  self.detailTextView.editable = NO;
  [self.view addSubview:self.detailTextView];

  NSString *dataFile = [[NSBundle mainBundle] pathForResource:@"richtext" ofType:@"json"];
  NSData *dataj = [NSData dataWithContentsOfFile:dataFile];//[dataFile dataUsingEncoding:NSUTF8StringEncoding];

  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:dataj
                                                       options:NSJSONReadingMutableContainers
                                                         error:nil];
  [[GDORichText alloc] initWithTextView:self.detailTextView].setContents([GDOPBDelta parseFromJson:json error:nil]);
  self.detailTextView.backgroundColor = [UIColor blueColor];


  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_MSEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void) {
      [self presentViewController:[[GDORichTextPlaygroundViewController alloc] initWithStyle:UITableViewStylePlain] animated:YES completion:nil];
  });
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
