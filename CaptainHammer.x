#import <UIKit/UIKit.h>
//#import <SpringBoard/SpringBoard.h>
#import <notify.h>
#import <libactivator/libactivator.h>
#import <objc/message.h>

#import "SafariRemoteDebugging.h"

#import <PonyDebugger/PDDebugger.h>

%config(generator=internal);

static BOOL isActive;

__attribute__((visibility("hidden")))
@interface CaptainHammer : NSObject <LAListener, UIActionSheetDelegate, UIAlertViewDelegate> {
@private
	UIActionSheet *actionSheet;
	UIAlertView *alertView;
	SEL handler;
}
+ (CaptainHammer *)sharedVillian;
- (void)toggleActivation;
@end

#define kHammerTime "com.rpetrich.captainhammer"

static void ActivateNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[CaptainHammer sharedVillian] toggleActivation];
}

static void WillEnterForegroundNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if (!isActive) {
		isActive = YES;
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), ActivateNotificationReceived, ActivateNotificationReceived, CFSTR(kHammerTime), NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
}

static void DidEnterBackgroundNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if (isActive) {
		isActive = NO;
		CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), ActivateNotificationReceived, CFSTR(kHammerTime), NULL);
	}
}

static void DidFinishLaunchingNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	/*PDDebugger *debugger = [PDDebugger defaultInstance];
	[debugger forwardAllNetworkTraffic];*/
}

@implementation CaptainHammer

static CaptainHammer *sharedVillian;

+ (void)load
{
	@autoreleasepool {
		sharedVillian = [[self alloc] init];
		CFNotificationCenterRef local = CFNotificationCenterGetLocalCenter();
		CFNotificationCenterAddObserver(local, DidFinishLaunchingNotificationReceived, DidFinishLaunchingNotificationReceived, (CFStringRef)UIApplicationDidFinishLaunchingNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		PDDebugger *debugger = [PDDebugger defaultInstance];
		[debugger autoConnect];
		[debugger enableViewHierarchyDebugging];
		[debugger enableNetworkTrafficDebugging];
		if (LASharedActivator.runningInsideSpringBoard) {
			if (![LASharedActivator hasSeenListenerWithName:@kHammerTime])
				[LASharedActivator assignEvent:[LAEvent eventWithName:LAEventNameVolumeUpHoldShort mode:LAEventModeApplication] toListenerWithName:@kHammerTime];
			[LASharedActivator registerListener:sharedVillian forName:@kHammerTime];
		} else {
			CFNotificationCenterAddObserver(local, WillEnterForegroundNotificationReceived, WillEnterForegroundNotificationReceived, (CFStringRef)UIApplicationDidFinishLaunchingNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
			CFNotificationCenterAddObserver(local, WillEnterForegroundNotificationReceived, WillEnterForegroundNotificationReceived, (CFStringRef)UIApplicationWillEnterForegroundNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
			CFNotificationCenterAddObserver(local, DidEnterBackgroundNotificationReceived, DidEnterBackgroundNotificationReceived, (CFStringRef)UIApplicationDidEnterBackgroundNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		}
	}
}

+ (CaptainHammer *)sharedVillian
{
	return sharedVillian;
}

- (void)newSheetWithTitle:(NSString *)title handler:(SEL)newHandler
{
	[alertView dismissWithClickedButtonIndex:-1 animated:YES];
	alertView.delegate = nil;
	alertView = nil;
	[actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
	actionSheet.delegate = nil;
	actionSheet = [[UIActionSheet alloc] init];
	actionSheet.delegate = self;
	actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	actionSheet.title = title;
	handler = newHandler;
}

- (void)showSheet
{
	actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:@"Cancel"];
	UIWindow *window = [[UIApplication sharedApplication] keyWindow] ?: [[UIApplication sharedApplication].windows objectAtIndex:0];
	UIView *view = window.rootViewController.view ?: [window.subviews objectAtIndex:0];
	[actionSheet showInView:view];
}

- (void)newAlertWithTitle:(NSString *)title handler:(SEL)newHandler
{
	[actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
	actionSheet.delegate = nil;
	actionSheet = nil;
	[alertView dismissWithClickedButtonIndex:-1 animated:YES];
	alertView.delegate = nil;
	alertView = nil;
	alertView = [[UIAlertView alloc] init];
	alertView.delegate = self;
	alertView.title = title;
	handler = newHandler;
}

- (void)showAlert
{
	alertView.cancelButtonIndex = [alertView addButtonWithTitle:@"Cancel"];
	[alertView show];
}

- (void)toggleActivation
{
	if (actionSheet || alertView) {
		[actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
		actionSheet.delegate = nil;
		actionSheet = nil;
		[alertView dismissWithClickedButtonIndex:-1 animated:YES];
		alertView.delegate = nil;
		alertView = nil;
	} else {
		[self newSheetWithTitle:@"CaptainHammer" handler:@selector(defaultSheetClicked:)];
		actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle:@"Force Crash"];
		[actionSheet addButtonWithTitle:@"Unique Identifier"];
		[actionSheet addButtonWithTitle:@"View Heirarchy"];
		[actionSheet addButtonWithTitle:@"Web Views"];
		[actionSheet addButtonWithTitle:@"Web Inspector"];
		[actionSheet addButtonWithTitle:@"Clear Pasteboard"];
		[self showSheet];
	}
}

- (void)showAndCopyMessage:(NSString *)message withTitle:(NSString *)title
{
	NSLog(@"CaptainHammer:\n%@", message);
	[UIPasteboard generalPasteboard].string = message;
	[self newAlertWithTitle:title handler:NULL];
	alertView.message = message;
	[self showAlert];
}

- (void)recursivelyAddViews:(NSArray *)views ofClass:(Class)class toMutableArray:(NSMutableArray *)array
{
	for (UIView *view in views) {
		if ([view isKindOfClass:class]) {
			[array addObject:view];
		}
		[self recursivelyAddViews:view.subviews ofClass:class toMutableArray:array];
	}
}

- (void)defaultSheetClicked:(NSInteger)buttonIndex
{
	switch (buttonIndex) {
		case 0:
			[self performSelector:@selector(forceCrash) withObject:nil afterDelay:0.0];
			break;
		case 1: {
			Class class = objc_getClass("MedialetsAnalyticsManager");
			NSString *string = [UIDevice currentDevice].uniqueIdentifier;
			if (class && [class respondsToSelector:@selector(md5DeviceID)]) {
				string = [string stringByAppendingFormat:@"\n%@", objc_msgSend(class, @selector(md5DeviceID))];
			}
			[self showAndCopyMessage:string withTitle:@"Unique Identifier"];
			break;
		}
		case 2: {
			NSMutableArray *descriptions = [NSMutableArray array];
			for (UIWindow *window in [UIApplication sharedApplication].windows) {
				[descriptions addObject:objc_msgSend(window, @selector(recursiveDescription))];
			}
			[self showAndCopyMessage:[descriptions componentsJoinedByString:@"\n\n"] withTitle:@"View Heirarchy"];
			break;
		}
		case 3: {
			NSMutableArray *webViews = [NSMutableArray array];
			[self recursivelyAddViews:[UIApplication sharedApplication].windows ofClass:[UIWebView class] toMutableArray:webViews];
			NSMutableArray *descriptions = [NSMutableArray array];
			for (UIWebView *webView in webViews) {
				[descriptions addObject:[NSString stringWithFormat:@"%@\n%@", webView, [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.outerHTML"]]];
			}
			[self showAndCopyMessage:[descriptions componentsJoinedByString:@"\n\n"] withTitle:@"Web Views"];
			break;
		}
		case 4: {
			if (kCFCoreFoundationVersionNumber >= 700.0)
				[self showAndCopyMessage:@"CaptainHammer enables debugging for all applications when Settings > Safari > Advanced > Web Inspector is enabled." withTitle:@"Safari Remote Inspector"];
			else if (SafariRemoteDebuggingEnable())
				[self showAndCopyMessage:SafariRemoteDebuggingGetAddress() withTitle:@"Safari Remote Inspector"];
			else
				[self showAndCopyMessage:@"Unable to setup remote inspector" withTitle:@"Safari Remote Inspector"];
			break;
		}
		case 5: {
			[self showAndCopyMessage:nil withTitle:@"Cleared Pasteboards"];
			[UIPasteboard generalPasteboard].items = nil;
			[UIPasteboard removePasteboardWithName:@"medialets-analytics"];
			NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
			NSString *path = [[libraryPath stringByAppendingPathComponent:@"Medialets"] stringByAppendingPathComponent:@"analytics.plist"];
			[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		}
	}
}

- (void)actionSheet:(UIActionSheet *)actionSheet_ didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	actionSheet.delegate = nil;
	actionSheet = nil;
	if (handler)
		objc_msgSend(self, handler, buttonIndex);
}

- (void)alertView:(UIAlertView *)alertView_ didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	alertView.delegate = nil;
	alertView = nil;
	if (handler)
		objc_msgSend(self, handler, buttonIndex);
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	notify_post(kHammerTime);
	event.handled = YES;
}

@end

typedef struct {
	unsigned _field1[8];
} WebInspectorEntitlement;

%hook WebInspectorRelay

- (BOOL)_hasRemoteInspectorEntitlement:(WebInspectorEntitlement)entitlement
{
	return YES;
}

%end
