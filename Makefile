SCRIPTS_PATH := Sources/Navigator/EPUB/Scripts

help:
	@echo "Usage: make <target>\n\n\
	  carthage-project\tGenerate the Carthage Xcode project\n\
	  scripts\t\tBundle the Navigator EPUB scripts\n\
	"

.PHONY: carthage-project
carthage-project:
	xcodegen -s Carthage/project.yml --use-cache --cache-path Carthage/.xcodegen

.PHONY: scripts
scripts:
	yarn --cwd "$(SCRIPTS_PATH)" install --frozen-lockfile
	yarn --cwd "$(SCRIPTS_PATH)" run format
	yarn --cwd "$(SCRIPTS_PATH)" run lint
	yarn --cwd "$(SCRIPTS_PATH)" run bundle
