# Makefile — GameTweak 构建配置
ARCHS = arm64
TARGET = iphone:clang:16.5:12.0
PROJECT_NAME = GameTweak

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
    -O2 \
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

# 编译后把 dylib 复制到项目根目录，方便取
after-stage::
	@cp -v $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/$(PROJECT_NAME).dylib ./$(PROJECT_NAME).dylib 2>/dev/null || true
	@echo "===== 编译完成 ====="
	@ls -la ./$(PROJECT_NAME).dylib 2>/dev/null || echo "dylib 未找到，检查上方错误"
