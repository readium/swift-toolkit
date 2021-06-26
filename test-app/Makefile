help:
	@echo "Usage: make <target> [lcp=<url>]\n\n\
Choose one of the following targets to generate:\n\
  spm\t\t(recommended) Integration with Swift Package Manager\n\
  carthage\tIntegration with Carthage\n\
  cocoapods\tIntegration with CocoaPods\n\
  dev\t\tIntegration with Git submodules and SPM, for contributors\n\n\
To enable Readium LCP, provide the liblcp URL EDRLab gave you, e.g.\n\
  $$ make spm lcp=https://...\n\
"

clean:
	@rm -f project.yml
	@rm -f Podfile*
	@rm -f Cartfile*
	@rm -rf Carthage
	@rm -rf Pods
	@rm -rf R2TestApp.xcodeproj
	@rm -rf R2TestApp.xcworkspace

spm: clean
ifdef lcp
	@echo "binary \"$(lcp)\"" > Cartfile
	carthage update --platform ios --cache-builds
	@cp Integrations/SPM/project+lcp.yml project.yml
else
	@cp Integrations/SPM/project.yml .
endif
	xcodegen generate
	@echo "\nopen R2TestApp.xcodeproj"

carthage: clean
ifdef lcp
	@cp Integrations/Carthage/project+lcp.yml project.yml
	@cp Integrations/Carthage/Cartfile+lcp Cartfile
	@echo "binary \"$(lcp)\"" >> Cartfile
else
	@cp Integrations/Carthage/project.yml .
	@cp Integrations/Carthage/Cartfile .
endif
	carthage update --platform ios --use-xcframeworks --cache-builds
	xcodegen generate
	@echo "\nopen R2TestApp.xcodeproj"

cocoapods: clean
ifdef lcp
	@sed -e "s>LCP_URL>$(lcp)>g" Integrations/CocoaPods/Podfile+lcp > Podfile
	@cp Integrations/CocoaPods/project+lcp.yml project.yml
else
	@cp Integrations/CocoaPods/project.yml .
	@cp Integrations/CocoaPods/Podfile .
endif
	xcodegen generate
	pod install
	@echo "\nopen R2TestApp.xcworkspace"

dev: clean
ifdef lcp
	@cp Integrations/Submodules/project+lcp.yml project.yml
	@echo "binary \"$(lcp)\"" > Cartfile
	carthage update --platform ios --cache-builds
else
	@cp Integrations/Submodules/project.yml .
endif
	git submodule update --init --recursive
	xcodegen generate
	@echo "\nopen R2TestApp.xcodeproj"
