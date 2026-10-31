ARCHS = arm64 arm64e
TARGET = iphone:16.5:14.0

include $(THEOS)/makefiles/common.mk

# Regenerate TL schema table: make schema SCHEMAS="path/a.tl path/b.tl"
schema::
	python3 tools/gen_schema.py Sources/tgapi/TLSchema.h $(SCHEMAS)

TWEAK_NAME = TGExtra

$(TWEAK_NAME)_FILES = $(shell find Sources \( -name '*.c' -o -name '*.m' -o -name '*.xm' \))
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -ISources/tgapi -Wno-deprecated-declarations
$(TWEAK_NAME)_FRAMEWORKS = CoreServices UIKit CoreText UniformTypeIdentifiers
$(TWEAK_NAME)_LOGOS_DEFAULT_GENERATOR = internal

# Copy TGExtra.bundle manually during the packaging step
after-stage::
	@echo ">>> Copying Choco.bundle into .deb package..."
	@mkdir -p $(THEOS_STAGING_DIR)/Library/Application\ Support/TGExtra
	@cp -a TGExtra.bundle $(THEOS_STAGING_DIR)/Library/Application\ Support/TGExtra
	@if [ -d python_runtime ]; then cp -a python_runtime $(THEOS_STAGING_DIR)/Library/Application\ Support/TGExtra/Python; find $(THEOS_STAGING_DIR)/Library/Application\ Support/TGExtra/Python \( -name '*.so' -o -name Python \) -type f -exec ldid -S {} \; ; fi

include $(THEOS_MAKE_PATH)/tweak.mk
