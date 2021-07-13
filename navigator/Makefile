.PHONY: carthage
carthage:
	# For R2Navigator, XcodeGen generates a different project every time for
	# some reason. Using the cache prevents this.
	xcodegen -s project-carthage.yml --use-cache --cache-path r2-navigator-swift.xcodeproj/.xcodegen
