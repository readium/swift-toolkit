SCRIPTS_PATH := Sources/Navigator/EPUB/Scripts

help:
	@echo "Usage: make <target>\n\n\
	  playground\t\tGenerate the Playground project\n\
	  podspecs\t\tGenerate the CocoaPods podspecs\n\
	  scripts\t\tBundle the Navigator EPUB scripts\n\
	  test\t\t\tRun unit tests\n\
	  lint-format\t\tVerify formatting\n\
	  format\t\tFormat sources\n\
	  update-locales\tUpdate the localization files\n\
	"

.SILENT:
.PHONY: playground
playground:
	cd Playground; \
	find . -name ".DS_Store" -delete; \
	xcodegen --use-cache --cache-path .xcodegen; \
	# The repository might be cloned to a different location than "swift-toolkit".
	# XcodeGen will use the name of the folder in the project, which is not desirable.
	# This will replace all occurrences of this folder by "swift-toolkit".
	perl -i -0777 -pe 'if (/name = (\S+); path = \.\.; /) { my $$n = $$1; s/name = \Q$$n\E; path = \.\./name = swift-toolkit; path = ../; s|/\* \Q$$n\E \*/|/* swift-toolkit */|g; }' Playground/Playground.xcodeproj/project.pbxproj

.PHONY: podspecs
podspecs:
	swift run --package-path BuildTools GeneratePodspecs

.PHONY: navigator-ui-tests-project
navigator-ui-tests-project:
	xcodegen -s Tests/NavigatorTests/UITests/project.yml

.PHONY: scripts
scripts:
	@which corepack >/dev/null 2>&1 || (echo "ERROR: corepack is required, please install it first\nhttps://pnpm.io/installation#using-corepack"; exit 1)

	cd $(SCRIPTS_PATH); \
	rm -rf "node_modules"; \
	corepack install; \
	pnpm install --frozen-lockfile; \
	pnpm run format; \
	pnpm run lint; \
	pnpm run bundle

.PHONY: update-scripts
update-scripts:
	@which corepack >/dev/null 2>&1 || (echo "ERROR: corepack is required, please install it first\nhttps://pnpm.io/installation#using-corepack"; exit 1)
	pnpm install --dir "$(SCRIPTS_PATH)"

.PHONY: lint-format
lint-format:
	swift run --package-path BuildTools swiftformat --lint .

.PHONY: format
f: format
format:
	swift run --package-path BuildTools swiftformat .

BRANCH ?= main

.PHONY: update-locales
update-locales:
	@which node >/dev/null 2>&1 || (echo "ERROR: node is required, please install it first"; exit 1)
ifndef DIR
	rm -rf thorium-locales
	git clone -b $(BRANCH) --single-branch --depth 1 https://github.com/edrlab/thorium-locales.git
endif
	node BuildTools/Scripts/convert-thorium-localizations.js thorium-locales
ifndef DIR
	rm -rf thorium-locales
endif
	make format
