#import <UIKit/UIKit2.h>
#import <SpringBoard/SpringBoard.h>
#import <notify.h>
#import <libactivator/libactivator.h>

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

@implementation CaptainHammer

static CaptainHammer *sharedVillian;

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	sharedVillian = [[self alloc] init];
	if (LASharedActivator.runningInsideSpringBoard) {
		if (![LASharedActivator hasSeenListenerWithName:@kHammerTime])
			[LASharedActivator assignEvent:[LAEvent eventWithName:LAEventNameVolumeUpHoldShort mode:LAEventModeApplication] toListenerWithName:@kHammerTime];
		[LASharedActivator registerListener:sharedVillian forName:@kHammerTime];
	} else {
		CFNotificationCenterRef local = CFNotificationCenterGetLocalCenter();
		CFNotificationCenterAddObserver(local, WillEnterForegroundNotificationReceived, WillEnterForegroundNotificationReceived, (CFStringRef)UIApplicationDidFinishLaunchingNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		CFNotificationCenterAddObserver(local, WillEnterForegroundNotificationReceived, WillEnterForegroundNotificationReceived, (CFStringRef)UIApplicationWillEnterForegroundNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		CFNotificationCenterAddObserver(local, DidEnterBackgroundNotificationReceived, DidEnterBackgroundNotificationReceived, (CFStringRef)UIApplicationDidEnterBackgroundNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
	[pool drain];
}

+ (CaptainHammer *)sharedVillian
{
	return sharedVillian;
}

- (void)newSheetWithTitle:(NSString *)title handler:(SEL)newHandler
{
	[alertView dismissWithClickedButtonIndex:-1 animated:YES];
	alertView.delegate = nil;
	[alertView release];
	alertView = nil;
	[actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
	actionSheet.delegate = nil;
	[actionSheet release];
	actionSheet = [[UIActionSheet alloc] init];
	actionSheet.delegate = self;
	actionSheet.alertSheetStyle = UIActionSheetStyleBlackTranslucent;
	actionSheet.title = title;
	handler = newHandler;
}

- (void)showSheet
{
	actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:@"Cancel"];
	UIWindow *window = [[UIApplication sharedApplication] keyWindow];
	UIView *view = window.rootViewController.view ?: [window.subviews objectAtIndex:0];
	[actionSheet showInView:view];
}

- (void)newAlertWithTitle:(NSString *)title handler:(SEL)newHandler
{
	[actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
	actionSheet.delegate = nil;
	[actionSheet release];
	actionSheet = nil;
	[alertView dismissWithClickedButtonIndex:-1 animated:YES];
	alertView.delegate = nil;
	[alertView release];
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
		[actionSheet release];
		actionSheet = nil;
		[alertView dismissWithClickedButtonIndex:-1 animated:YES];
		alertView.delegate = nil;
		[alertView release];
		alertView = nil;
	} else {
		[self newSheetWithTitle:@"CaptainHammer" handler:@selector(defaultSheetClicked:)];
		actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle:@"Force Crash"];
		[actionSheet addButtonWithTitle:@"Unique Identifier"];
		[actionSheet addButtonWithTitle:@"View Heirarchy"];
		[actionSheet addButtonWithTitle:@"Web Views"];
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
			objc_msgSend(self, @selector(forceCrash));
			break;
		case 1:
			[self showAndCopyMessage:[UIDevice currentDevice].uniqueIdentifier withTitle:@"Unique Identifier"];
			break;
		case 2: {
			NSMutableArray *descriptions = [NSMutableArray array];
			for (UIWindow *window in [UIApplication sharedApplication].windows) {
				[descriptions addObject:[window recursiveDescription]];
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
	}
}

- (void)actionSheet:(UIActionSheet *)actionSheet_ didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	actionSheet.delegate = nil;
	[actionSheet release];
	actionSheet = nil;
	if (handler)
		objc_msgSend(self, handler, buttonIndex);
}

- (void)alertView:(UIAlertView *)alertView_ didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	alertView.delegate = nil;
	[alertView release];
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
