//
// Created by Larry Tin on 12/11/16.
//

#import "GDOPBAttribute+FluentInterface.h"

#define kImplementMethodChainingNumber(name) \
- (GDOPBAttribute *(^)(int name))set##name { \
    return ^GDOPBAttribute *(int name) { \
        self.name = name; \
        return self; \
    }; \
}

#define kImplementMethodChaining(name) \
- (GDOPBAttribute *(^)(id name))set##name { \
    return ^GDOPBAttribute *(id name) { \
        self.name = name; \
        return self; \
    }; \
}

@implementation GDOPBAttribute (FluentInterface)

kImplementMethodChaining(Color);
kImplementMethodChaining(Background);
kImplementMethodChaining(Size);
kImplementMethodChaining(Font);
kImplementMethodChaining(Link);
kImplementMethodChainingNumber(Bold);
kImplementMethodChainingNumber(Italic);
kImplementMethodChainingNumber(Underline);
kImplementMethodChainingNumber(Strike);
kImplementMethodChainingNumber(Code);
kImplementMethodChainingNumber(Script);

kImplementMethodChaining(Extras);

kImplementMethodChainingNumber(Align);

kImplementMethodChaining(Width);
kImplementMethodChaining(Height);
@end
