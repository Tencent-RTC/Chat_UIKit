
//  Created by Tencent on 2024/11/1.
//  Copyright © 2024 Tencent. All rights reserved.

#import <Foundation/Foundation.h>
#import <TUICore/TUIThemeManager.h>
#import <TUICore/TUICore.h>

NS_ASSUME_NONNULL_BEGIN

@interface TUISwift : NSObject

#pragma mark - Color
+ (UIColor *)tuiDemoDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiConversationDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiConversationGroupDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)timCommonDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiDynamicColor:(NSString *)colorKey themeModule:(TUIThemeModule)themeModule defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiChatDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiContactDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)rgb:(CGFloat)r g:(CGFloat)g b:(CGFloat)b;
+ (UIColor *)rgba:(CGFloat)r g:(CGFloat)g b:(CGFloat)b a:(CGFloat)a;
+ (UIColor *)tImageMessageCell_Progress_Color;
+ (UIColor *)tVideoMessageCell_Progress_Color;
+ (UIColor *)tController_Background_Color;
+ (UIColor *)tController_Background_Color_Dark;
+ (UIColor *)tuiTranslationDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiVoiceToTextDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiGroupNoteDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiPollDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;
+ (UIColor *)tuiOfficialAccountDynamicColor:(NSString *)colorKey defaultColor:(NSString *)defaultColor;

#pragma mark - Image
+ (UIImage *)defaultGroupAvatarImageByGroupType:(NSString * _Nullable)groupType;
+ (UIImage *)defaultAvatarImage;
+ (UIImage *)tuiDemoDynamicImage:(NSString *)imageKey defaultImage:(UIImage *)defaultImage;
+ (UIImage *)tuiCoreDynamicImage:(NSString *)imageKey defaultImage:(UIImage *)defaultImage;
+ (UIImage *)timCommonDynamicImage:(NSString *)imageKey defaultImage:(UIImage *)defaultImage;
+ (UIImage *)tuiContactDynamicImage:(NSString *)imageKey defaultImage:(UIImage *)defaultImage;
+ (UIImage *)tuiConversationDynamicImage:(NSString *)imageKey defaultImage:(UIImage *)defaultImage;
+ (UIImage *)tuiConversationGroupDynamicImage:(NSString *)imageKey defaultImage:(UIImage *)defaultImage;
+ (UIImage *)tuiConversationMarkDynamicImage:(NSString *)imageKey defaultImage:(UIImage *)defaultImage;
+ (UIImage *)tuiDynamicImage:(NSString *)imageKey themeModule:(TUIThemeModule)themeModule defaultImage:(UIImage *)defaultImage;
+ (UIImage *)timCommonBundleImage:(NSString *)key;
+ (UIImage *)tuiConversationCommonBundleImage:(NSString *)key;
+ (UIImage *)tuiCoreBundleThemeImage:(NSString *)imageKey defaultImage:(NSString *)defaultImage;
+ (UIImage *)tuiChatBundleThemeImage:(NSString *)imageName defaultImage:(NSString *)defaultImage;
+ (UIImage *)tuiChatCommonBundleImage:(NSString *)imageName;
+ (UIImage *)tuiConversationBundleThemeImage:(NSString *)imageKey defaultImage:(NSString *)defaultImage;
+ (UIImage *)tuiChatDynamicImage:(NSString *)imageKey defaultImage:(UIImage *)defaultImage;
+ (UIImage *)tuiTranslationBundleThemeImage:(NSString *)imageName defaultImage:(NSString *)defaultImage;
+ (UIImage *)tuiVoiceToTextBundleThemeImage:(NSString *)imageName defaultImage:(NSString *)defaultImage;
+ (UIImage *)timCommonBundleThemeImage:(NSString *)imageName defaultImage:(NSString *)defaultImage;
+ (UIImage *)tuiContactCommonBundleImage:(NSString *)imageName;
+ (UIImage *)tuiSearchBundleThemeImage:(NSString *)imageName defaultImage:(NSString *)defaultImage;
+ (UIImage *)tuiGroupNoteBundleThemeImage:(NSString *)imageName defaultImage:(NSString *)defaultImage;
+ (UIImage *)tuiPollBundleThemeImage:(NSString *)imageName defaultImage:(NSString *)defaultImage;
+ (UIImage *)tuiOfficialAccountBundleThemeImage:(NSString *)imageName defaultImage:(NSString *)defaultImage;

#pragma mark - String
+ (NSString *)timCommonLocalizableString:(NSString *)key;
+ (NSString *)tuiChatLocalizableString:(NSString *)key;
+ (NSString *)tuiKitLocalizableString:(NSString *)key;
+ (NSString *)tuiChatFaceImagePath:(NSString *)imageName;
+ (NSString *)tuiConversationGroupImagePath:(NSString *)imageName;
+ (NSString *)tFileMessageCell_ReuseId;
+ (NSString *)tImageMessageCell_ReuseId;

#pragma mark - Path
+ (void)tuiRegisterThemeResourcePath:(NSString *)path themeModule:(TUIThemeModule)themeModule;
+ (NSString *)tuiDemoImagePath:(NSString *)path;
+ (NSString *)tuiDemoImagePath_Minimalist:(NSString *)path;
+ (NSString *)tuiCoreImagePath:(NSString *)path;
+ (NSString *)timCommonImagePath:(NSString *)path;
+ (NSString *)tuiConversationImagePath:(NSString *)imageName;
+ (NSString *)tuiContactImagePath:(NSString *)imageName;
+ (NSString *)tuiContactImagePath_Minimalist:(NSString *)imageName;
+ (NSString *)tuiBundlePath:(NSString *)name key:(NSString *)key;
+ (NSString *)tuiChatImagePath_Minimalist:(NSString *)name;
+ (NSString *)tuiChatImagePath:(NSString *)name;
+ (NSString *)tuiConversationImagePath_Minimalist:(NSString *)imageName;
+ (NSString *)tuiKit_Image_Path;
+ (NSString *)tuiKit_Video_Path;
+ (NSString *)tuiKit_Voice_Path;
+ (NSString *)tuiKit_File_Path;
+ (NSString *)tuiKit_DB_Path;
+ (NSString *)tFaceCell_ReuseId;
+ (NSString *)tuiTranslationThemePath;
+ (NSString *)tuiVoiceToTextThemePath;
+ (NSString *)tuiChatThemePath;
+ (NSString *)tuiConversationGroupThemePath;
+ (NSString *)tuiConversationMarkImagePath:(NSString *)imageName;
+ (NSString *)tuiSearchThemePath;
+ (NSString *)tuiSearchImagePath:(NSString *)imageName;
+ (NSString *)tuiGroupNoteThemePath;
+ (NSString *)tuiPollThemePath;
+ (NSString *)tuiOfficialAccountThemePath;
+ (NSString *)timCommonThemePath;

#pragma mark - Size and primitive value
+ (CGSize)tuiPopView_Arrow_Size;
+ (CGSize)timDefaultEmojiSize;
+ (CGSize)tVideoMessageCell_Play_Size;
+ (CGSize)tFileMessageCell_Container_Size;
+ (CGSize)tVoiceMessageCell_Duration_Size;
+ (CGSize)tTextView_Button_Size;
+ (CGSize)tPersonalCommonCell_Image_Size;
+ (CGSize)tGroupMemberCell_Head_Size;
+ (CGSize)kTIMDefaultEmoji_Size;

+ (CGFloat)kScale375:(CGFloat)x;
+ (CGFloat)kScale390:(CGFloat)x;
+ (CGFloat)statusBar_Height;
+ (CGFloat)navBar_Height;
+ (CGFloat)tabBar_Height;
+ (CGFloat)screen_Width;
+ (CGFloat)screen_Height;
+ (CGFloat)tTextView_TextView_Height_Min;
+ (CGFloat)tTextView_TextView_Height_Max;
+ (CGFloat)bottom_SafeHeight;
+ (CGFloat)tTextView_Height;
+ (CGFloat)tTextMessageCell_Text_Width_Max;
+ (CGFloat)tFaceMessageCell_Image_Height_Max;
+ (CGFloat)tFaceMessageCell_Image_Width_Max;
+ (CGFloat)tMenuCell_Margin;
+ (CGFloat)tMergeMessageCell_Width_Max;
+ (CGFloat)tMergeMessageCell_Height_Max;
+ (CGFloat)tFaceView_Margin;
+ (CGFloat)tFaceView_Page_Padding;
+ (CGFloat)tLine_Height;
+ (CGFloat)tFaceView_Page_Height;
+ (CGFloat)tImageMessageCell_Image_Width_Max;
+ (CGFloat)tImageMessageCell_Image_Height_Max;
+ (CGFloat)tVideoMessageCell_Image_Height_Max;
+ (CGFloat)tVideoMessageCell_Image_Width_Max;
+ (CGFloat)tVoiceMessageCell_Back_Width_Min;
+ (CGFloat)tVoiceMessageCell_Back_Width_Max;
+ (CGFloat)tVoiceMessageCell_Max_Duration;
+ (CGFloat)tTextView_Margin;
+ (CGFloat)tConversationCell_Height;

#pragma mark - Other
+ (BOOL)isRTL;
+ (BOOL)is_IPhoneX;

@end

NS_ASSUME_NONNULL_END
