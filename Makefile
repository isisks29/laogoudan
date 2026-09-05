# Makefile — GameTweak 构建配置
ARCHS = arm64
TARGET = iphone:clang:16.5:12.0

PROJECT_NAME = GameTweak
INSTALL_PATH = /Library/Frameworks/$(PROJECT_NAME).framework

# 源文件
$(PROJECT_NAME)_FILES = \
    src/Tweak.xm \
    src/Config.m \
    src/AntiDetect.m \
    src/MemoryUtils.m \
    src/IL2CPPUtils.m \
    src/FeatureManager.m \
    src/MacroManager.m \
    src/UI/TweakUI.m \
    src/fishhook/fishhook.c

# 编译选项
$(PROJECT_NAME)_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -DNDEBUG \
    -Isrc \
    -Isrc/fishhook \
    -Isrc/UI \
    -Wno-unused-variable \
    -Wno-unused-function \
    -Wno-format \
    -Wno-objc-property-no-attribute

# 链接框架
$(PROJECT_NAME)_LDFLAGS = \
    -framework Foundation \
    -framework UIKit \
    -framework CoreFoundation \
    -framework QuartzCore

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk

after-package::
	@echo "===== GameTweak 构建完成 ====="
	@echo "产物: $(THEOS_PACKAGE_DIR)/$(PROJECT_NAME)_$(PACKAGE_VERSION)_iphoneos-arm.deb"
	@echo ""
	@echo "三大模块:"
	@echo "  1. 反检测: ptrace/sysctl Hook + dyld隐藏 + 越狱反制 + 注入器感知"
	@echo "  2. 功能开关: 双连点/解限/灵敏/解断/名字大小/粘合/视野/内显/防录制/回弹"
	@echo "  3. 宏操作: 16分/吐球(按住循环) + 4分(点击触发)，直接调用IL2CPP不模拟触摸"
