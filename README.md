# Github Action for Building and Signing Flutter iOS Apps

This action builds and signs the Flutter iOS app for temporary distribution for on-device testing. It was developed due to the lack of ability to build and test iOS apps on Windows machines. If you are on a MacOS machine, this action may not be necessary for you.

## Usage

The following guide will walk you through the basic steps to use this action. Some parts of the guide will be specific to non-MacOS platforms.

### Prerequisites

- Windows, Linux or MacOS machine
- A properly configured Apple Developer Account (see [Tutorial: Setting up Apple Developer Account for iOS App Development](#tutorial-setting-up-apple-developer-account-for-ios-app-development))
- A Flutter project

### Phase I: Flutter Setup

1. **Ensure proper iOS build support is enabled for your Flutter project**
    1. Check the existence of the `ios` directory
    2. Check that `ios/Podfile` file exists. 
        - If the `ios` directory exists but the `ios/Podfile` file does not, this may be an indication that the iOS build support was enabled on a non-MacOS platform. in this case, you need to delete the ios directory and refer to [Tutorial: Setting up Flutter Project for iOS on non-MacOS Platforms](#tutorial-setting-up-flutter-project-for-ios-on-non-macos-platforms) for the correct setup

2. **Ensure the Flutter project have an acceptable bundle identifier**
    1. Open `ios/Runner.xcworkspace` in a text editor and search for `PRODUCT_BUNDLE_IDENTIFIER`. The value should be in the format `com.example.appname` (with only alphanumeric characters and periods). If the value is not in this format, you must change it to a valid one before proceeding.
        - Refer to this [StackOverflow post](https://stackoverflow.com/questions/51534616/how-to-change-package-name-in-flutter) for more information on how to change the bundle identifier

3. **Updating `ios/Podfile` to disable code signing for Pod libraries**
    1. Open `ios/Podfile` and navigate to the section that contains the following lines:

        ```pod
        post_install do |installer|
          installer.pods_project.targets.each do |target|
            flutter_additional_ios_build_settings(target)
          end
        end
        ```
    2. Modify the `post_install` section to the following:
        ```pod
        post_install do |installer|
          installer.pods_project.targets.each do |target|
            flutter_additional_ios_build_settings(target)

            # For disabling code signing for any Pod libraries
            # Signing Pod libraries will cause the signing process to fail
            target.build_configurations.each do |config|
              config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
              config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
            end
          end
        end
        ```

4. Once the Flutter project is properly configured, you can proceed to the next phase.


## Tutorial: Setting up Flutter Project for iOS on non-MacOS Platforms

## Tutorial: Setting up Apple Developer Account for iOS App Development
