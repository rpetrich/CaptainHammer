TWEAK_NAME = CaptainHammer
CaptainHammer_FILES = CaptainHammer.x
CaptainHammer_FRAMEWORKS = UIKit
CaptainHammer_LDFLAGS = -lactivator

ADDITIONAL_CFLAGS = -std=c99
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 3.0

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
