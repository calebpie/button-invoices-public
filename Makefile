# Button Invoices build commands. Run `make` or `make help` for the list.

PROJECT   := ButtonInvoices.xcodeproj
BUILD_DIR := build
XCODEGEN  := swift run --package-path Tools/BuildTools -c release xcodegen
SIM_APP   := $(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Button Invoices.app
IOS_APP   := $(BUILD_DIR)/Build/Products/Debug-iphoneos/Button Invoices.app
SIMULATOR ?= iPhone 17

.PHONY: help setup generate open sim ios test sample-pdfs seed clean

help:
	@echo "make setup        One time, after signing into Xcode: find your team ID, write Configs/Signing.xcconfig"
	@echo "make generate     Regenerate ButtonInvoices.xcodeproj from project.yml"
	@echo "make open         Regenerate, then open the project in Xcode"
	@echo "make sim          Build and launch the app in the iPhone Simulator (SIMULATOR=\"iPad Air 11-inch (M4)\" for another)"
	@echo "make ios          Build, install and launch the app on the iPhone connected by cable"
	@echo "make test         Run the InvoiceKit tests (naming, SKUs, matching, totals, PDF, photo cutout)"
	@echo "make sample-pdfs  Re-create the example invoices as PDFs in build/sample-pdfs, to compare with Examples/"
	@echo "make seed         Rebuild the starting catalog in App/Resources/Seed from the newest invoice workbook"
	@echo "make clean        Delete build output"

Configs/Signing.xcconfig:
	cp Configs/Signing.xcconfig.template $@

setup:
	Tools/scripts/setup-signing.sh

generate: Configs/Signing.xcconfig
	$(XCODEGEN) generate --quiet

open: generate
	open $(PROJECT)

sim: generate
	xcodebuild -project $(PROJECT) -scheme ButtonInvoices -configuration Debug \
		-derivedDataPath $(BUILD_DIR) -destination 'generic/platform=iOS Simulator' -quiet build
	Tools/scripts/run-sim.sh "$(SIM_APP)" "$(SIMULATOR)"

ios: generate
	xcodebuild -project $(PROJECT) -scheme ButtonInvoices -configuration Debug \
		-derivedDataPath $(BUILD_DIR) -destination 'generic/platform=iOS' \
		-allowProvisioningUpdates -quiet build
	Tools/scripts/install-ios.sh "$(IOS_APP)"

test:
	swift test --package-path Packages/InvoiceKit

sample-pdfs:
	swift test --package-path Packages/InvoiceKit --filter 'rendersTheExamples|liftsHerPhotos'
	@echo "Wrote build/sample-pdfs (cutouts of the raw photos are in build/sample-pdfs/cutouts)"
	open build/sample-pdfs

seed:
	python3 Tools/seed/extract_seed.py

clean:
	rm -rf $(BUILD_DIR)
