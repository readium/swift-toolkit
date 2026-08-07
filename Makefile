SCRIPTS_PATH := Sources/Navigator/EPUB/Scripts

help:
	@echo "Usage: make <target>\n\n\
	  playground\t\tGenerate the Playground project\n\
	  \t\t\tUse 'lcp=<url>' to enable LCP.\n\
	  dev\t\t\tGenerate both the Playground and TestApp projects for development\n\
	  \t\t\tUse 'lcp=<url>' to enable LCP.\n\
	  podspecs\t\tGenerate the CocoaPods podspecs\n\
	  scripts\t\tBundle the Navigator EPUB scripts\n\
	  test\t\t\tRun unit tests\n\
	  \t\t\tUse 'only=<target>' to run a single test target.\n\
	  lint-format\t\tVerify formatting\n\
	  format\t\tFormat sources\n\
	  update-locales\tUpdate the localization files\n\
	"

.PHONY: test
test:
	./scripts/test.sh $(only)

.SILENT:
.PHONY: playground
playground:
	cp Playground/Support/Playground.xctestplan Playground/Playground.xctestplan
ifdef lcp
	@curl --fail --silent --show-error -L --create-dirs --output Playground/R2LCPClient/Package.swift "$(lcp)"
	cd Playground; xcodegen -s Support/project+lcp.yml --project . --project-root .
	# The plan only declares the test targets of the package. Add the LCP tests,
	# whose target identifier is only known once the project has been generated.
	scripts/gen-lcp-testplan.py Playground/Playground.xctestplan Playground/Playground.xcodeproj/project.pbxproj
else
	rm -rf Playground/R2LCPClient
	cd Playground; xcodegen -s Support/project.yml --project . --project-root .
endif
	# The repository might be cloned to a different location than "swift-toolkit".
	# XcodeGen will use the name of the folder in the project, which is not desirable.
	# This will replace all occurrences of this folder by "swift-toolkit".
	perl -i -0777 -pe 'if (/name = "?([^";\n]+)"?; path = \.\.; /) { my $$n = $$1; s/name = "?\Q$$n\E"?; path = \.\.;/name = swift-toolkit; path = ..;/; s|/\* \Q$$n\E \*/|/* swift-toolkit */|g; }' Playground/Playground.xcodeproj/project.pbxproj

.PHONY: dev
dev: playground
	$(MAKE) -C TestApp dev lcp=$(lcp)
	@echo "\n☝️  Open Support/Readium.xcworkspace"

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
	node scripts/convert-thorium-localizations.js thorium-locales
ifndef DIR
	rm -rf thorium-locales
endif
	make format
