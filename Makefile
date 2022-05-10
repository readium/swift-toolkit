SCRIPTS_PATH := Sources/Navigator/EPUB/Scripts

help:
	@echo "Usage: make <target>\n\n\
	  carthage-project\tGenerate the Carthage Xcode project\n\
	  scripts\t\tBundle the Navigator EPUB scripts\n\
	"

.PHONY: carthage-project
carthage-project:
	xcodegen -s Support/Carthage/project.yml --use-cache --cache-path Support/Carthage/.xcodegen

.PHONY: scripts
scripts:
	yarn --cwd "$(SCRIPTS_PATH)" install --frozen-lockfile
	yarn --cwd "$(SCRIPTS_PATH)" run format
	yarn --cwd "$(SCRIPTS_PATH)" run lint
	yarn --cwd "$(SCRIPTS_PATH)" run bundle

.PHONY: test
test:
	# To limit to a particular test suite: -only-testing:R2SharedTests
	xcodebuild test -scheme "Readium-Package" -destination "platform=iOS Simulator,name=iPhone 12" | xcbeautify -q

