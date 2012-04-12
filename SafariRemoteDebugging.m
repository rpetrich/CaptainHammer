//
//  SafariRemoteDebugging.m
//  MedialetsShowcase
//
//  Created by Ryan Petrich on 11-12-07.
//  Copyright (c) 2011 Medialets, Inc. All rights reserved.
//

#import "SafariRemoteDebugging.h"

#include <netdb.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <dlfcn.h>

@interface WebInspectorServerConnectionHTTP : NSObject
- (id)initWithSocketFileDescriptor:(int)fd;
@end

extern CFRunLoopRef WebThreadRunLoop(void);

static Class connectionClass;

static void accept_callback(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
    if (callbackType != kCFSocketAcceptCallBack)
        return;
    CFSocketNativeHandle fd = *(CFSocketNativeHandle*)data;
    // Seems to require leaking? that can't be right, but it crashes if I don't
    [[connectionClass alloc] initWithSocketFileDescriptor:fd];
}

static CFRunLoopRef activeRunLoop;
static CFRunLoopSourceRef runLoopSource;

static void EnterBackgroundCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    CFRunLoopRemoveSource(activeRunLoop, runLoopSource, kCFRunLoopCommonModes);
}

static void EnterForegroundCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    CFRunLoopAddSource(activeRunLoop, runLoopSource, kCFRunLoopCommonModes);
}

bool SafariRemoteDebuggingEnable(void)
{
    if (connectionClass)
        return true;
    if (!(connectionClass = objc_getClass("WebInspectorServerConnectionHTTP")))
        return false;
    
    struct sockaddr_in address;
    address.sin_len = sizeof(struct sockaddr_in);
    address.sin_family = AF_INET;
    address.sin_port = htons(9999);
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    memset(&(address.sin_zero), 0, sizeof(address.sin_zero));
    
    CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_STREAM, 0, kCFSocketAcceptCallBack, accept_callback, NULL);
    if (!socket) {
        return false;
    }
    
    CFDataRef addr = CFDataCreate(kCFAllocatorDefault, (UInt8*)&address, sizeof(address));
    
    int yes = 1;
    setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
    
    // now bind
    CFSocketError err = CFSocketSetAddress(socket, addr);
    CFRelease(addr);
    if (err != kCFSocketSuccess)
        return false;
    
    // Try getting the web thread's run loop
    void *webkit = dlopen("/System/Library/PrivateFrameworks/WebKit.framework/WebKit", RTLD_LAZY);
    CFRunLoopRef (*webThreadRunLoop)(void) = webkit ? dlsym(webkit, "WebThreadRunLoop") : NULL;
    CFRunLoopRef runLoop = webThreadRunLoop ? webThreadRunLoop() : NULL;
    activeRunLoop = (CFRunLoopRef)CFRetain(runLoop ?: CFRunLoopGetMain());
    
    // Schedule the socket
    runLoopSource = CFSocketCreateRunLoopSource (kCFAllocatorDefault, socket, 0);
    CFRunLoopAddSource(activeRunLoop, runLoopSource, kCFRunLoopCommonModes);

    CFNotificationCenterRef center = CFNotificationCenterGetLocalCenter();
    CFNotificationCenterAddObserver(center, NULL, EnterBackgroundCallback, CFSTR("UIApplicationDidEnterBackgroundNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(center, NULL, EnterForegroundCallback, CFSTR("UIApplicationWillEnterForegroundNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);

    CFRelease(socket);
    return true;
}

NSString *SafariRemoteDebuggingGetAddress(void)
{
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        struct ifaddrs *addr = interfaces;
        while (addr) {
            if (addr->ifa_addr->sa_family == AF_INET) {
                if (strcmp(addr->ifa_name, "en0") == 0) {
                    NSString *result = [NSString stringWithFormat:@"http://%s:9999/", inet_ntoa(((struct sockaddr_in *)addr->ifa_addr)->sin_addr)];
                    freeifaddrs(interfaces);
                    return result;
                }
            }
            addr = addr->ifa_next;
        }
        freeifaddrs(interfaces);
    }
    return nil;
}

