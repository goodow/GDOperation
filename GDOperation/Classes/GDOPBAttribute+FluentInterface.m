//
// Created by Larry Tin on 12/11/16.
//

#import "GDOPBAttribute+FluentInterface.h"
#import "GDOPBDelta+GDOperation.h"

#define kImplementMethodChainingSetNumber(name) \
- (GDOPBAttribute *(^)(int name))set##name { \
    return ^GDOPBAttribute *(int name) { \
        self.name = name; \
        return self; \
    }; \
}

#define kImplementMethodChainingSet(name) \
- (GDOPBAttribute *(^)(id name))set##name { \
    return ^GDOPBAttribute *(id name) { \
        if (!name) { \
          name = NULL_SENTINEL_CHARACTER; \
        } \
        self.name = name; \
        return self; \
    }; \
}


//#define kImplementMethodChainingGet(name1, name2) \
//- (NSString *(^)())get##name1 { \
//    return ^NSString * { \
//        if ([NULL_SENTINEL_CHARACTER isEqualToString:self.##name2]) { \
//          return nil; \
//        } \
//        return self.##name2; \
//    }; \
//}

@implementation GDOPBAttribute (FluentInterface)


kImplementMethodChainingSet(Color);
//kImplementMethodChainingGet(Color, color);
kImplementMethodChainingSet(Background);
kImplementMethodChainingSet(Size);
kImplementMethodChainingSet(Font);
kImplementMethodChainingSet(Link);
kImplementMethodChainingSetNumber(Bold);
kImplementMethodChainingSetNumber(Italic);
kImplementMethodChainingSetNumber(Underline);
kImplementMethodChainingSetNumber(Strike);
kImplementMethodChainingSetNumber(Code);
kImplementMethodChainingSetNumber(Script);

kImplementMethodChainingSet(Extras);

kImplementMethodChainingSetNumber(Align);

kImplementMethodChainingSet(Width);
kImplementMethodChainingSet(Height);


@end
