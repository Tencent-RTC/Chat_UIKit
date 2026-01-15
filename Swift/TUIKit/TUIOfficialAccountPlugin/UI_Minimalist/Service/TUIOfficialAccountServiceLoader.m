#import "TUIOfficialAccountServiceLoader.h"
#import <TUIOfficialAccountPlugin/TUIOfficialAccountPlugin-Swift.h>

@implementation TUIOfficialAccountServiceLoader

+ (void)load {
    [TUIOfficialAccountExtensionObserver swiftLoad];
    [TUIOfficialAccountService swiftLoad];
}

@end
