export TARGET = iphone:clang:latest
export ARCHS = armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = WOLListener
WOLListener_OBJC_FILES = Listener.xm
WOLListener_FRAMEWORKS = UIKit
WOLListener_LIBRARIES = activator

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	#PreferenceLoader plist
	$(ECHO_NOTHING)if [ -f Preferences.plist ]; then mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/WOLListener; cp Preferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/WOLListener/; fi$(ECHO_END)
