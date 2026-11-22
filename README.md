# Anti-Spoilers for Telegram iOS

An unofficial feature concept on top of Telegram iOS 13.0.0 (`release-13.0.0`). It is not affiliated with Telegram.

You add a film, series or game, and every incoming post that mentions it is covered until you tap it. When you have finished it, press **I'm Caught Up** and everything becomes visible again.

## What it does

- **Settings > Anti-Spoilers**: an on/off switch, hiding of photos and videos, topics, popular topics, finished topics, and chats where nothing is hidden.
- **Topics with keywords**: keyword chips with suggestions. `GTA 6`, `GTA-6` and `#gta6` are the same keyword, `GTA 60` is not.
- **Hide as Spoiler** in the menu of any incoming post. The topic is taken from the post and can be edited before saving.
- **I'm Caught Up** in the menu of a hidden post and in the topic. The topic moves to the Caught Up section.
- **What to hide** is chosen in every topic: everything about it, or **Only Spoilers** (Telegram Premium), when news and reviews stay visible and only posts marked as spoilers are covered.
- Covered places: bubbles and albums, chat list, search, replies, the reply and forward panel, pinned messages, shared media and the in-app banner.
- Text uses Telegram's own spoiler effect, media uses the spoiler overlay. Your own messages are never hidden.

## Demo mode

There is a local demo account with fictional chats. It needs no API keys and no phone number, and the account never connects to the network.

1. Follow the [compilation guide](#telegram-ios-source-code-compilation-guide) below, but clone this branch:
   ```
   git clone --recursive -j8 -b anti-spoiler https://github.com/likefnaticcs/anti-spoilers.git
   ```
2. In the configuration file set `"api_id": "1"` and `"api_hash": "placeholder"`. With these values the app opens the demo by itself and keeps its data.
3. Launch arguments: `--demo` starts again with clean data, `--demo-premium` (together with `--demo`) adds Premium to the demo account.

A new post about GTA 6 arrives a few seconds after every launch. Built with Xcode 26.6 and Bazel 9.2.0, with app extensions disabled.

## What is not real yet

- **Only Spoilers needs a server.** In the demo the posts are marked by hand with `SpoilerClassificationMessageAttribute`, no AI runs in the app.
- **Popular topics are hardcoded.** The release version would receive them from the server.
- **Settings are stored on the device** and are not synchronized between devices.
- **Not covered**: system push notifications, link previews (they stay hidden even after the text is revealed), the Links tab, polls, voice messages, stories, rich articles and captions in the fullscreen gallery.
- Keywords match whole words, without word forms. Strings are English only.

## Where the code is

| Part | Path |
| --- | --- |
| Settings, matching, popular topics | `submodules/TelegramUIPreferences/Sources/AntiSpoilerSettings.swift` |
| Which messages are hidden, topic suggestions | `submodules/AccountContext/Sources/AntiSpoiler.swift` |
| Settings screens | `submodules/SettingsUI/Sources/AntiSpoiler/` |
| Label in the bubble | `submodules/TelegramUI/Components/Chat/ChatMessageAntiSpoilerBubbleContentNode/` |
| Post menu | `submodules/TelegramUI/Sources/AntiSpoilerContextMenu.swift` |
| Spoiler mark of a message | `submodules/TelegramCore/Sources/SyncCore/SyncCore_SpoilerClassificationMessageAttribute.swift` |
| Demo mode | `submodules/TelegramUI/Sources/DemoMode.swift`, `submodules/TelegramCore/Sources/Account/DemoAccount.swift` |

The feature and the demo mode are separate commits, so the feature can be taken without the demo.

---

# Telegram iOS Source Code Compilation Guide

We welcome all developers to use our API and source code to create applications on our platform.
There are several things we require from **all developers** for the moment.

# Creating your Telegram Application

1. [**Obtain your own api_id**](https://core.telegram.org/api/obtaining_api_id) for your application.
2. Please **do not** use the name Telegram for your app — or make sure your users understand that it is unofficial.
3. Kindly **do not** use our standard logo (white paper plane in a blue circle) as your app's logo.
3. Please study our [**security guidelines**](https://core.telegram.org/mtproto/security_guidelines) and take good care of your users' data and privacy.
4. Please remember to publish **your** code too in order to comply with the licences.

# Quick Compilation Guide

## Get the Code

```
git clone --recursive -j8 https://github.com/TelegramMessenger/Telegram-iOS.git
```

## Setup Xcode

Install Xcode (directly from https://developer.apple.com/download/applications or using the App Store).

## Adjust Configuration

1. Generate a random identifier:
```
openssl rand -hex 8
```
2. Create a new Xcode project. Use `Telegram` as the Product Name. Use `org.{identifier from step 1}` as the Organization Identifier.
3. Open `Keychain Access` and navigate to `Certificates`. Locate `Apple Development: your@email.address (XXXXXXXXXX)` and double tap the certificate. Under `Details`, locate `Organizational Unit`. This is the Team ID.
4. Edit `build-system/template_minimal_development_configuration.json`. Use data from the previous steps.

## Generate an Xcode project

```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=build-system/template_minimal_development_configuration.json \
    --xcodeManagedCodesigning
```

# Advanced Compilation Guide

## Xcode

1. Copy and edit `build-system/appstore-configuration.json`.
2. Copy `build-system/fake-codesigning`. Create and download provisioning profiles, using the `profiles` folder as a reference for the entitlements.
3. Generate an Xcode project:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=configuration_from_step_1.json \
    --codesigningInformationPath=directory_from_step_2
```

## IPA

1. Repeat the steps from the previous section. Use distribution provisioning profiles.
2. Run:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    build \
    --configurationPath=...see previous section... \
    --codesigningInformationPath=...see previous section... \
    --buildNumber=100001 \
    --configuration=release_arm64
```

# FAQ

## Xcode is stuck at "build-request.json not updated yet"

Occasionally, you might observe the following message in your build log:
```
"/Users/xxx/Library/Developer/Xcode/DerivedData/Telegram-xxx/Build/Intermediates.noindex/XCBuildData/xxx.xcbuilddata/build-request.json" not updated yet, waiting...
```

Should this occur, simply cancel the ongoing build and initiate a new one.

## Telegram_xcodeproj: no such package 

Following a system restart, the auto-generated Xcode project might encounter a build failure accompanied by this error:
```
ERROR: Skipping '@rules_xcodeproj_generated//generator/Telegram/Telegram_xcodeproj:Telegram_xcodeproj': no such package '@rules_xcodeproj_generated//generator/Telegram/Telegram_xcodeproj': BUILD file not found in directory 'generator/Telegram/Telegram_xcodeproj' of external repository @rules_xcodeproj_generated. Add a BUILD file to a directory to mark it as a package.
```

If you encounter this issue, re-run the project generation steps in the README.


# Tips

## Codesigning is not required for simulator-only builds

Add `--disableProvisioningProfiles`:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=path-to-configuration.json \
    --codesigningInformationPath=path-to-provisioning-data \
    --disableProvisioningProfiles
```

## Versions

Each release is built using a specific Xcode version (see `versions.json`). The helper script checks the versions of the installed software and reports an error if they don't match the ones specified in `versions.json`. It is possible to bypass these checks:

```
python3 build-system/Make/Make.py --overrideXcodeVersion build ... # Don't check the version of Xcode
```
