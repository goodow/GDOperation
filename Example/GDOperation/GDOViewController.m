//
//  GDOViewController.m
//  GDOperation
//
//  Created by Larry Tin on 12/10/2016.
//  Copyright (c) 2016 Larry Tin. All rights reserved.
//

#import "GDOViewController.h"
#import "GDORichText.h"
#import "GPBMessage+JsonFormat.h"
#import "GDOFirebaseAdapter.h"
#import "GDOTextView.h"
@import Firebase;

@interface GDOViewController ()
@property(strong, nonatomic) FIRDatabaseReference *ref;
@property(strong) GDORichText *richText;
@end

@implementation GDOViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Do any additional setup after loading the view, typically from a nib.
  UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height)];
  [self.view addSubview:textView];
  self.richText = GDOTextView.attachView(textView);
  textView.editable = NO;

  self.ref = [[FIRDatabase database] reference];
  GDOFirebaseAdapter *adapter = [[GDOFirebaseAdapter alloc] initWithRef:[self.ref child:@"richText/default"]];
  adapter.onTextChange = ^(GDOPBDelta *delta, GDOPBDelta *contents) {
      self.richText.setContents(contents);
  };
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

@end
