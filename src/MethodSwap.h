// src/MethodSwap.h
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static inline void methodSwizzle(Class cls, SEL originalSel, SEL newSel)
{
    Method origMethod = class_getInstanceMethod(cls, originalSel);
    Method newMethod = class_getInstanceMethod(cls, newSel);
    if (!origMethod || !newMethod) return;
    
    BOOL addOK = class_addMethod(cls,
                                  originalSel,
                                  method_getImplementation(newMethod),
                                  method_getTypeEncoding(newMethod));
    if(addOK){
        class_replaceMethod(cls,
                            newSel,
                            method_getImplementation(origMethod),
                            method_getTypeEncoding(origMethod));
    }else{
        method_exchangeImplementations(origMethod, newMethod);
    }
}
