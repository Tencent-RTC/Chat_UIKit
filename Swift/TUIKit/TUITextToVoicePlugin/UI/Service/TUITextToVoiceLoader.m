#import "TUITextToVoiceLoader.h"
#import <TUITextToVoicePlugin/TUITextToVoicePlugin-Swift.h>


@implementation TUITextToVoiceLoader
+ (void)load {
    [TUITextToVoiceExtensionObserver swiftLoad];
}
@end
