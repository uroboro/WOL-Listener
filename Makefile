export TARGET = iphone:clang:latest

include theos/makefiles/common.mk

TWEAK_NAME = WOLListener
WOLListener_OBJC_FILES = Listener.xm
WOLListener_FRAMEWORKS = UIKit
WOLListener_LIBRARIES = activator

include $(THEOS_MAKE_PATH)/tweak.mk
