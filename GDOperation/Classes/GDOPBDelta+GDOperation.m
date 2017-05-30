//
// Created by Larry Tin on 12/11/16.
//

#import "GDOPBDelta+GDOperation.h"

enum GDOOperationType {
  Insert, Retain, Delete
};

const NSString *NULL_SENTINEL_CHARACTER = @"\uE000";
const int NULL_ENUM_VALUE = 15;

@interface GDOOperationIterator : NSObject
@property NSArray<GDOPBDelta_Operation *> *ops;
@property unsigned long long index;
@property unsigned long long offset;

@end

@implementation GDOOperationIterator {

}
- (instancetype)initWithOps:(NSArray *)ops {
  self = [super init];
  if (self) {
    self.ops = ops;
  }
  return self;
}


- (BOOL)hasNext {
  return self.index < self.ops.count;
}

- (GDOPBDelta_Operation *)next:(unsigned long long)length {
  if (length <= 0) {
    length = NSUIntegerMax;
  }
  if (![self hasNext]) {
    GDOPBDelta_Operation *operation = GDOPBDelta_Operation.message;
    operation.retain_p = NSUIntegerMax;
    return operation;
  }
  GDOPBDelta_Operation *nextOp = self.ops[self.index];
  unsigned long long offset = self.offset;
  unsigned long long opLength = [self.class length:nextOp];
  if (length >= opLength - offset) {
    length = opLength - offset;
    self.index += 1;
    self.offset = 0;
  } else {
    self.offset += length;
  }

  if (nextOp.delete_p) {
    GDOPBDelta_Operation *operation = GDOPBDelta_Operation.message;
    operation.delete_p = length;
    return operation;
  } else {
    GDOPBDelta_Operation *retOp = GDOPBDelta_Operation.message;
    if (nextOp.hasAttributes) {
      retOp.attributes = nextOp.attributes;
    }
    if (nextOp.retain_p) {
      retOp.retain_p = length;
    } else if (nextOp.insert.length) {
      retOp.insert = [nextOp.insert substringWithRange:NSMakeRange(offset, length)];
    } else {
      // offset should == 0, length should == 1
      retOp.insertEmbed = nextOp.insertEmbed;
    }
    return retOp;
  }
}

- (GDOPBDelta_Operation *)peek {
  return self.ops[self.index];
}

- (unsigned long long)peekLength {
  if (self.index < self.ops.count) {
    // Should never return 0 if our index is being managed correctly
    return [self.class length:self.ops[self.index]] - self.offset;
  } else {
    return NSUIntegerMax;
  }
}

- (enum GDOOperationType)peekType {
  if (![self hasNext]) {
    return Retain;
  }
  GDOPBDelta_Operation *op = self.ops[self.index];
  if (op.delete_p) {
    return Delete;
  } else if (op.retain_p) {
    return Retain;
  } else {
    return Insert;
  }
}

+ (unsigned long long)length:(GDOPBDelta_Operation *)op {
  if (op.delete_p) {
    return op.delete_p;
  } else if (op.retain_p) {
    return op.retain_p;
  } else {
    return op.insert.length ?: 1;
  }
}

+ (GDOPBAttribute *)attributesCompose:(GDOPBAttribute *)attributes1 with:(GDOPBAttribute *)attributes2 keepNull:(BOOL)keepNull {
  attributes1 = attributes1 ?: GDOPBAttribute.message;
  attributes2 = attributes2 ?: GDOPBAttribute.message;
  GDOPBAttribute *attributes = attributes1.copy;
  [attributes mergeFrom:attributes2];
  if (!keepNull) {
    for (GPBFieldDescriptor *field in GDOPBAttribute.descriptor.fields) {
      if (!GPBMessageHasFieldSet(attributes, field)) {
        continue;
      }
      switch (field.fieldType) {
        case GPBFieldTypeSingle:
          switch (field.dataType) {
            case GPBDataTypeString:
              if ([NULL_SENTINEL_CHARACTER isEqualToString:[attributes valueForKey:field.name]]) {
                GPBClearMessageField(attributes, field);
              }
              break;
            case GPBDataTypeEnum: {
              int32_t rawValue = GPBGetMessageInt32Field(attributes, field);
              if (NULL_ENUM_VALUE == rawValue || ([field.enumDescriptor.name isEqualToString:GDOPBAttribute_Bool_EnumDescriptor().name] && rawValue == GDOPBAttribute_Bool_False)) {
                GPBClearMessageField(attributes, field);
              }
            }
              break;
            default:
              break;
          }
          break;
        case GPBFieldTypeMap: {
          NSMutableDictionary<NSString *, NSString *> *extras = [attributes valueForKey:field.name];
          for (NSString *key in extras) {
            if ([NULL_SENTINEL_CHARACTER isEqualToString:extras[key]]) {
              [extras removeObjectForKey:key];
            }
          }
        }
          break;
        case GPBFieldTypeRepeated:
        default:
          break;
      }
    }
  }
  return attributes;
}

+ (GDOPBAttribute *)attributesTransform:(GDOPBAttribute *)attributes1 with:(GDOPBAttribute *)attributes2 priority:(BOOL)priority {
  return nil;
}
@end

@implementation GDOPBDelta (GDOperation)

- (GDOPBDelta *(^)(NSString *text, GDOPBAttribute *attributes))insert {
  return ^GDOPBDelta *(NSString *text, GDOPBAttribute *attributes) {
      if (!text.length) {
        return self;
      }
      GDOPBDelta_Operation *op = [[GDOPBDelta_Operation alloc] init];
      op.insert = text;
      op.attributes = attributes;
      return self.push(op);
  };
}

- (GDOPBDelta *(^)(unsigned long long, GDOPBAttribute *))retain_p {
  return ^GDOPBDelta *(unsigned long long int length, GDOPBAttribute *attributes) {
      if (length <= 0) {
        return self;
      }
      GDOPBDelta_Operation *op = [[GDOPBDelta_Operation alloc] init];
      op.retain_p = length;
      op.attributes = attributes;
      return self.push(op);
  };
}

- (GDOPBDelta *(^)(unsigned long long))delete {
  return ^GDOPBDelta *(unsigned long long int length) {
      if (length <= 0) {
        return self;
      }
      GDOPBDelta_Operation *op = [[GDOPBDelta_Operation alloc] init];
      op.delete_p = length;
      return self.push(op);
  };
}

- (GDOPBDelta *(^)(GDOPBDelta *other))compose {
  return ^GDOPBDelta *(GDOPBDelta *other) {
      GDOOperationIterator *thisIter = [[GDOOperationIterator alloc] initWithOps:self.opsArray];
      GDOOperationIterator *otherIter = [[GDOOperationIterator alloc] initWithOps:other.opsArray];
      GDOPBDelta *delta = GDOPBDelta.message;
      while (thisIter.hasNext || otherIter.hasNext) {
        if (otherIter.peekType == Insert) {
          delta.push([otherIter next:0]);
        } else if (thisIter.peekType == Delete) {
          delta.push([thisIter next:0]);
        } else {
          unsigned long long length = MIN(thisIter.peekLength, otherIter.peekLength);
          GDOPBDelta_Operation *thisOp = [thisIter next:length];
          GDOPBDelta_Operation *otherOp = [otherIter next:length];
          if (otherOp.retain_p) {
            GDOPBDelta_Operation *newOp = GDOPBDelta_Operation.message;
            if (thisOp.retain_p) {
              newOp.retain_p = length;
            } else {
              newOp.insert = thisOp.insert;
            }
            // Preserve null when composing with a retain, otherwise remove it for inserts
            newOp.attributes = [GDOOperationIterator attributesCompose:thisOp.attributes with:otherOp.attributes keepNull:thisOp.retain_p];
            delta.push(newOp);
            // Other op should be delete, we could be an insert or retain
            // Insert + delete cancels out
          } else if (otherOp.delete_p && thisOp.retain_p) {
            delta.push(otherOp);
          }
        }
      }
      return delta.chop();
  };
}

- (GDOPBDelta *(^)(GDOPBDelta *other, BOOL priority))transform {
  return ^GDOPBDelta *(GDOPBDelta *other, BOOL priority) {
      return nil;
  };
}

- (void (^)(BOOL (^predicate)(GDOPBDelta *line, GDOPBAttribute *attributes, int i), NSString *newline))eachLine {
  return ^(BOOL (^predicate)(GDOPBDelta *, GDOPBAttribute *, int), NSString *newline) {
      newline = newline ?: @"\n";
      GDOOperationIterator *iter = [[GDOOperationIterator alloc] initWithOps:self.opsArray];
      GDOPBDelta *line = GDOPBDelta.message;
      int i = 0;
      while (iter.hasNext) {
        if (iter.peekType != Insert) return;
        GDOPBDelta_Operation *thisOp = iter.peek;
        NSInteger index = NSNotFound;
        if (thisOp.insert.length) {
          unsigned long long start = [GDOOperationIterator length:thisOp] - iter.peekLength;
          NSRange range = [thisOp.insert rangeOfString:newline options:0 range:NSMakeRange(start, NSUIntegerMax)];
          index = range.location;
        }
        if (index == NSNotFound) {
          line.push([iter next:0]);
        } else if (index > 0) {
          line.push([iter next:index]);
        } else {
          if (!predicate(line, [iter next:1].attributes, i)) {
            return;
          }
          i += 1;
          line = GDOPBDelta.message;
        }
      }
      if (line.opsArray_Count) {
        predicate(line, GDOPBAttribute.message, i);
      }
  };
}

- (GDOPBDelta *(^)(GDOPBDelta_Operation *newOp))push {
  return ^GDOPBDelta *(GDOPBDelta_Operation *newOp) {
      NSUInteger index = self.opsArray_Count;
      newOp = newOp.copy;
      if (index > 0) {
        GDOPBDelta_Operation *lastOp = self.opsArray.lastObject;
        if (newOp.delete_p && lastOp.delete_p) {
          GDOPBDelta_Operation *operation = GDOPBDelta_Operation.message;
          operation.delete_p = newOp.delete_p + lastOp.delete_p;
          self.opsArray[index - 1] = operation;
          return self;
        }
        // Since it does not matter if we insert before or after deleting at the same index,
        // always prefer to insert first
        if (lastOp.delete_p && (newOp.insert.length || newOp.hasInsertEmbed)) {
          if (index == 1) {
            [self.opsArray insertObject:newOp atIndex:0];
            return self;
          }
          index -= 1;
          lastOp = self.opsArray[index - 1];
        }
        if ([newOp.attributes isEqual:lastOp.attributes]) {
          if (newOp.insert.length && lastOp.insert.length) {
            GDOPBDelta_Operation *operation = GDOPBDelta_Operation.message;
            operation.insert = [lastOp.insert stringByAppendingString:newOp.insert];
            self.opsArray[index - 1] = operation;
            if (newOp.hasAttributes) operation.attributes = newOp.attributes;
            return self;
          } else if (newOp.retain_p && lastOp.retain_p) {
            GDOPBDelta_Operation *operation = GDOPBDelta_Operation.message;
            operation.retain_p = lastOp.retain_p + newOp.retain_p;
            self.opsArray[index - 1] = operation;
            if (newOp.hasAttributes) operation.attributes = newOp.attributes;
            return self;
          }
        }
      }
      [self.opsArray insertObject:newOp atIndex:index];
      return self;
  };
}

- (GDOPBDelta *(^)())chop {
  return ^GDOPBDelta *() {
      GDOPBDelta_Operation *lastOp = self.opsArray.lastObject;
      if (lastOp.retain_p && !lastOp.hasAttributes) {
        [self.opsArray removeLastObject];
      }
      return self;
  };
}
@end