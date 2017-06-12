//
// Created by Larry Tin on 2017/6/11.
//

#import "GDCFirebaseChannel.h"
#import "Firebase.h"
#import "GDCBusProvider.h"
#import "GDCMessageImpl.h"
#import "NSObject+GDChannel.h"

@interface GDCFirebaseChannel ()
@property FIRDatabaseReference *ref;
@end

@implementation GDCFirebaseChannel {

}
- (instancetype)init {
  self = [super init];
  if (self) {
    NSString *clientId = GDCBusProvider.clientId;
    _ref = [[FIRDatabase database] referenceWithPath:[@"bus/queue" stringByAppendingPathComponent:clientId]];

    __weak GDCFirebaseChannel *weakSelf = self;
    [_ref observeEventType:FIRDataEventTypeChildAdded withBlock:^(FIRDataSnapshot *snapshot) {
        NSDictionary *msg = snapshot.value[@"send"];
        NSString *topic = [clientId stringByAppendingPathComponent:msg[@"topic"]];
        id payload = msg[payloadKey];
        GDCOptions *options = [GDCOptions parseFromJson:msg[optionsKey] error:nil];
        [weakSelf.bus sendLocal:topic payload:payload options:options replyHandler:^(id <GDCAsyncResult> asyncResult) {
            GDCMessageImpl *msg = asyncResult.result;
            NSDictionary *reply = [msg toJsonWithTopic:NO];
            [[snapshot.ref child:@"reply"] setValue:reply];
            [snapshot.ref onDisconnectRemoveValue];
        }];
    }];
  }

  return self;
}

@end