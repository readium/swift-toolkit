version = `git describe --tags --abbrev=0 2> /dev/null`
ifdef commit
	version = $(commit)
endif

help:
	@echo "Usage: make <target> [lcp=<url>]\n\n\
Choose one of the following targets to generate:\n\
\n\
  from the \033[1;33mmain\033[0m branch only:\n\
    \033[1mspm\033[0m\t\t\t(recommended) Integration with Swift Package Manager\n\
    \033[1mcarthage\033[0m\tIntegration with Carthage\n\
    \033[1mcocoapods\033[0m\tIntegration with CocoaPods\n\
\n\
  from the \033[1;33mmain\033[0m or \033[1;33mdevelop\033[0m branches:\n\
    \033[1mdev\033[0m\t\tIntegration with local folders and SPM, for contributors\n\n\
To enable Readium LCP, provide the liblcp URL EDRLab gave you, e.g.\n\
  $$ make spm lcp=https://...\n\
"

clean:
	@rm -f project.yml
	@rm -f Podfile*
	@rm -f Cartfile*
	@rm -rf Carthage
	@rm -rf Pods
	@rm -rf TestApp.xcodeproj
	@rm -rf TestApp.xcworkspace
	@rm -rf TestApp.xctestplan
	@rm -rf R2LCPClient

spm: clean
ifdef lcp
	@cp Integrations/SPM/project+lcp.yml project.yml
	curl --create-dirs --output R2LCPClient/Package.swift "$(lcp)"
	# Downgrades the SPM version to work with Xcode 12.4
	@sed -i '' -e 's/5.5/5.3.0/g' R2LCPClient/Package.swift
else
	@cp Integrations/SPM/project.yml .
endif
ifdef commit
	@sed -i '' -e "s>VERSION>revision: $(commit)>g" project.yml
else
	@sed -i '' -e "s>VERSION>from: $(version)>g" project.yml
endif
	xcodegen generate
	@echo "\nopen TestApp.xcodeproj"

carthage: clean
ifdef commit
	@echo "github \"readium/swift-toolkit\" \"$(commit)\"" > Cartfile
else
	@echo "github \"readium/swift-toolkit\" ~> $(version)" > Cartfile
endif

ifdef lcp
	@cp Integrations/Carthage/project+lcp.yml project.yml
	@echo "binary \"$(lcp)\"" >> Cartfile
else
	@cp Integrations/Carthage/project.yml .
endif
	carthage update --verbose --platform ios --use-xcframeworks --cache-builds --no-use-binaries
	xcodegen generate
	@echo "\nopen TestApp.xcodeproj"

cocoapods: clean
ifdef lcp
	@sed -e "s>LCP_URL>$(lcp)>g" Integrations/CocoaPods/Podfile+lcp > Podfile
	@cp Integrations/CocoaPods/project+lcp.yml project.yml
else
	@cp Integrations/CocoaPods/project.yml .
	@cp Integrations/CocoaPods/Podfile .
endif
	@sed -i '' -e "s>VERSION>$(version)>g" Podfile
	xcodegen generate
	pod install
	@echo "\nopen TestApp.xcworkspace"

dev: clean
ifdef lcp
	@cp Integrations/Local/project+lcp.yml project.yml
	curl --create-dirs --output R2LCPClient/Package.swift "$(lcp)"
	# Downgrades the SPM version to work with Xcode 12.4
	@sed -i '' -e 's/5.5/5.3.0/g' R2LCPClient/Package.swift
else
	@cp Integrations/Local/project.yml .
endif
	@cp -r Integrations/Local/TestApp.xcworkspace .
	@cp -r Integrations/Local/TestApp.xctestplan .
	xcodegen generate
	@echo "\nopen TestApp.xcworkspace"

