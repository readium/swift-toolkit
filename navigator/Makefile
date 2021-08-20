.PHONY: carthage scripts
SCRIPTS_PATH := r2-navigator-swift/EPUB/Scripts

help:
	@echo "Usage: make <target>\n\n\
	  carthage\tGenerate the Carthage Xcode project\n\
	  scripts\tBundle EPUB scripts with Webpack\n\
	  lint-scripts\tCheck quality of EPUB scripts\n\
	"

scripts:
	yarn --cwd "$(SCRIPTS_PATH)" run format
	yarn --cwd "$(SCRIPTS_PATH)" run bundle

lint-scripts:
	yarn --cwd "$(SCRIPTS_PATH)" run lint

carthage:
	# For R2Navigator, XcodeGen generates a different project every time for
	# some reason. Using the cache prevents this.
	xcodegen -s project-carthage.yml --use-cache --cache-path r2-navigator-swift.xcodeproj/.xcodegen
