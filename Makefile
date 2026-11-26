TARGET := iphone:clang:latest:14.0
# rootless 越狱（Dopamine / palera1n 2.x）：
# THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1

INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DouyinEQ
DouyinEQ_FILES = DouyinTweak.x
DouyinEQ_FRAMEWORKS = UIKit Foundation
DouyinEQ_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
