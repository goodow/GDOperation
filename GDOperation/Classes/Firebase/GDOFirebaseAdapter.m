//
// Created by Larry Tin on 2017/5/30.
//

#import "GDOFirebaseAdapter.h"
#import "Firebase.h"
#import "GoodowOperation.pbobjc.h"
#import "GDOPBDelta+GDOperation.h"
#import "GPBMessage+JsonFormat.h"

static const NSString *CHARACTERS = @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

@interface GDOFirebaseAdapter ()
@property FIRDatabaseReference *ref;
@property BOOL ready;
@property BOOL zombie;
@property GDOPBDelta *document;
@property unsigned long long revision;
@property unsigned long long checkpointRevision;
@property NSMutableDictionary<NSString *, GDOPBDelta *> *pendingReceivedRevisions;

@end

@implementation GDOFirebaseAdapter {

}
- (instancetype)initWithRef:(FIRDatabaseReference *)ref {
  self = [super init];
  if (self) {
    self.ref = ref;
    self.document = GDOPBDelta.message.insert(@"\n", nil);
    self.pendingReceivedRevisions = @{}.mutableCopy;

    [self monitorHistory];
  }

  return self;
}

- (void)dealloc {
  _zombie = YES;
}

- (void)monitorHistory {
  __weak GDOFirebaseAdapter *weak = self;
  // Get the latest checkpoint as a starting point so we don't have to re-play entire history.
  [[self.ref child:@"checkpoint"] observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *snapshot) {
      if (weak.zombie) {return;} // just in case we were cleaned up before we got the checkpoint data.
      if (snapshot.value != NSNull.null) {
        NSString *revisionId = snapshot.value[@"id"];
        NSArray *ops = snapshot.value[@"o"];
        if (ops && revisionId) {
          ops = [GDOFirebaseAdapter canonicalizeOps:ops replaceNullAttribute:NO];
          GDOPBDelta *delta = [weak parseRevision:ops];
          if (!delta) {
            // If a misbehaved client adds a bad operation, just ignore it.
            NSLog(@"Invalid operation. %@, %@, %@", weak.ref, revisionId, snapshot.value);
          }
          weak.pendingReceivedRevisions[revisionId] = delta;
          weak.checkpointRevision = [GDOFirebaseAdapter revisionFromId:revisionId];
          [weak monitorHistoryStartingAt:weak.checkpointRevision + 1];
          return;
        }
      }
      weak.checkpointRevision = 0;
      [weak monitorHistoryStartingAt:weak.checkpointRevision];
  }];
}

- (void)monitorHistoryStartingAt:(unsigned long long)revision {
  FIRDatabaseQuery *historyRef = [[self.ref child:@"history"] queryStartingAtValue:nil childKey:[GDOFirebaseAdapter revisionToId:revision]];
  __weak GDOFirebaseAdapter *weak = self;
  [historyRef observeEventType:FIRDataEventTypeChildAdded withBlock:^(FIRDataSnapshot *revisionSnapshot) {
      NSString *revisionId = revisionSnapshot.key;
      NSArray *ops = [GDOFirebaseAdapter canonicalizeOps:revisionSnapshot.value[@"o"] replaceNullAttribute:YES];
      GDOPBDelta *delta = [weak parseRevision:ops];
      if (!delta) {
        NSLog(@"Invalid operation. %@, %@, %@", weak.ref, revisionId, revisionSnapshot.value);
      }
      weak.pendingReceivedRevisions[revisionId] = delta;
      if (weak.ready) {
        [weak handlePendingReceivedRevisions];
      }
  }];

  [historyRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *snapshot) {
      [weak handleInitialRevisions];
  }];
}

- (void)handleInitialRevisions {
  NSAssert(!self.ready, @"Should not be called multiple times.");

  // Compose the checkpoint and all subsequent revisions into a single operation to apply at once.
  self.revision = self.checkpointRevision;
  NSString *revisionId = [GDOFirebaseAdapter revisionToId:self.revision];
  NSMutableDictionary<NSString *, GDOPBDelta *> *pending = self.pendingReceivedRevisions;
  while (pending[revisionId]) {
    self.document = self.document.compose(pending[revisionId]);
    [pending removeObjectForKey:revisionId];
    self.revision++;
    revisionId = [GDOFirebaseAdapter revisionToId:self.revision];
  }

  if (self.onTextChange) {
    GDOPBDelta *initDelta = self.document.compose(GDOPBDelta.message.retain_p(self.document.length -1, nil).delete(1));
    self.onTextChange(initDelta, self.document);
  }
  self.ready = YES;
}

- (void)handlePendingReceivedRevisions {
  NSMutableDictionary<NSString *, GDOPBDelta *> *pending = self.pendingReceivedRevisions;
  NSString *revisionId = [GDOFirebaseAdapter revisionToId:self.revision];
  while (pending[revisionId]) {
    self.revision++;
    self.document = self.document.compose(pending[revisionId]);
    if (self.onTextChange) {
      self.onTextChange(pending[revisionId], self.document);
    }
    [pending removeObjectForKey:revisionId];
    revisionId = [GDOFirebaseAdapter revisionToId:self.revision];
  }
}

- (GDOPBDelta *)parseRevision:(NSArray *)ops {
  if (!ops) {
    return GDOPBDelta.message;
  }
  return [GDOPBDelta parseFromJson:@{@"ops": ops} error:nil];
}

+ (NSMutableArray *)canonicalizeOps:(NSArray *)ops replaceNullAttribute:(BOOL)replaceNullAttribute {
  NSMutableArray *toRtn = @[].mutableCopy;
  for (NSDictionary *o in ops) {
    NSMutableDictionary *op = o.mutableCopy;
    [toRtn addObject:op];
    if (op[@"insert"] && ![op[@"insert"] isKindOfClass:NSString.class]) {
      op[@"insertEmbed"] = op[@"insert"];
      [op removeObjectForKey:@"insert"];
    }
    if (!replaceNullAttribute) {
      continue;
    }
    NSMutableDictionary *attributes = [op[@"attributes"] mutableCopy];
    for (NSString *key in op[@"attributes"]) {
      if ([@[@"bold", @"italic", @"underline", @"strike", @"code"] containsObject:key]) {
        if (![NULL_SENTINEL_CHARACTER isEqualToString:attributes[key]]) {
          continue;
        }
        attributes[key] = @(GDOPBAttribute_Bool_False);
      } else if ([@[@"script", @"align"] containsObject:key]) {
        if (![NULL_SENTINEL_CHARACTER isEqualToString:attributes[key]]) {
          continue;
        }
        attributes[key] = @(NULL_ENUM_VALUE);
      }
    }
    op[@"attributes"] = attributes;
  }
  return toRtn;
}

+ (NSString *)revisionToId:(unsigned long long)revision {
  if (revision == 0) {
    return @"A0";
  }

  NSString *str = @"";
  while (revision > 0) {
    unsigned long long digit = (revision % CHARACTERS.length);
    str = [[CHARACTERS substringWithRange:NSMakeRange(digit, 1)] stringByAppendingString:str];
    revision -= digit;
    revision /= CHARACTERS.length;
  }

  // Prefix with length (starting at 'A' for length 1) to ensure the id's sort lexicographically.
  NSString *prefix = [CHARACTERS substringWithRange:NSMakeRange(str.length + 9, 1)];
  return [prefix stringByAppendingString:str];
}

+ (unsigned long long)revisionFromId:(NSString *)revisionId {
  assert (revisionId.length > 0 && [revisionId characterAtIndex:0] == [CHARACTERS characterAtIndex:revisionId.length + 8]);
  unsigned long long revision = 0;
  for (int i = 1; i < revisionId.length; i++) {
    revision *= CHARACTERS.length;
    revision += [CHARACTERS rangeOfString:[revisionId substringWithRange:NSMakeRange(i, 1)]].location;
  }
  return revision;
}

@end
