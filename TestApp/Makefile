version = `git describe --tags --abbrev=0 2> /dev/null`
ifdef commit
	version = $(commit)
endif

help:
	@echo "Usage: make <target> [lcp=<url>]\n\n\
Choose one of the following targets to generate:\n\
  spm\t\t(recommended) Integration with Swift Package Manager\n\
  carthage\tIntegration with Carthage\n\
  cocoapods\tIntegration with CocoaPods\n\
  dev\t\tIntegration with local folders (e.g. Git submodules) and SPM, for contributors\n\n\
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

spm: clean
ifdef lcp
	@echo "binary \"$(lcp)\"" > Cartfile
	carthage update --platform ios --cache-builds
	@cp Integrations/SPM/project+lcp.yml project.yml
else
	@cp Integrations/SPM/project.yml .
endif
ifdef commit
	@sed -i "" -e "s>VERSION>revision: $(commit)>g" project.yml
else
	@sed -i "" -e "s>VERSION>from: $(version)>g" project.yml
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
	carthage update --verbose --platform ios --use-xcframeworks --cache-builds
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
	@sed -i "" -e "s>VERSION>$(version)>g" Podfile
	xcodegen generate
	pod install
	@echo "\nopen TestApp.xcworkspace"

dev: clean
ifdef lcp
	@cp Integrations/Local/project+lcp.yml project.yml
	@echo "binary \"$(lcp)\"" > Cartfile
	carthage update --platform ios --cache-builds
else
	@cp Integrations/Local/project.yml .
endif
	xcodegen generate
	@cp -r Integrations/Local/TestApp.xcworkspace .
	@echo "\nopen TestApp.xcworkspace"

