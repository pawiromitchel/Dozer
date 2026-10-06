TESTING_DIR := /Library/Developer/CommandLineTools/Library/Developer
# Swift Testing lives outside the default search paths when only the Command Line Tools are installed.
TEST_FLAGS := $(if $(wildcard /Applications/Xcode.app),,-Xswiftc -F$(TESTING_DIR)/Frameworks -Xlinker -F$(TESTING_DIR)/Frameworks -Xlinker -rpath -Xlinker $(TESTING_DIR)/Frameworks -Xlinker -rpath -Xlinker $(TESTING_DIR)/usr/lib)

app:
	@Scripts/build-app.sh release

debug:
	@Scripts/build-app.sh debug

run: debug
	@pkill -x Dozer || true
	@open build/Dozer.app

test:
	@swift test $(TEST_FLAGS)

install: app
	@pkill -x Dozer || true
	@rm -rf /Applications/Dozer.app
	@cp -R build/Dozer.app /Applications/
	@open /Applications/Dozer.app

zip: app
	@cd build && ditto -c -k --keepParent Dozer.app Dozer.zip && echo "Built build/Dozer.zip"

# Regenerates the README demo with the app's real drawing code (Tests/DozerTests/DemoGIF.swift).
demo-gif:
	@DOZER_DEMO_GIF=$(CURDIR)/Stuff/demo.gif swift test --filter DemoGIF $(TEST_FLAGS)
	@ls -lh Stuff/demo.gif

clean:
	@rm -rf .build build

.PHONY: app debug run test install zip demo-gif clean
