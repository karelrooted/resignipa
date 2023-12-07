# resignipa

resign ipa and install to apple device (iOS, TVOS) using fastlane and cfgutil on MacOS

## Requirements

- [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12)
- [Apple Configurator](https://apps.apple.com/us/app/apple-configurator/id1037126344?mt=12)
- [Homebrew](https://brew.sh)

## Usage

### Install
```
git clone https://github.com/karelrooted/resignipa.git && cd resignipa
```
### Interactive mode: choose certificate and profile manully
```
bash resignipa.sh -i <path/to/ipa>
```

### Automatic mode: can be use for cron auto refresh so sideload app doesn't expire

Before adding cronjob, you have to follow this onetime only step first

1. in Terminal
```
cd resignipa && open resignipa.xcodeproj
```
2. in Xcode
choose the device you want to install in the running destinatin list, click `resignipa` with blue icon in the top left, choose `resignipa` target, open `Signing & Capabilities` and select your `Team` and type in your unique BUNDLE_IDENTIFIER .
3. in Terminal
```
xcodebuild -target resignipa PRODUCT_BUNDLE_IDENTIFIER=<your.bundle.id> -allowProvisioningUpdates 2>/dev/null | grep --fixed-strings --after-context=2 'Signing Identity:' 
cd -
```
4. the output signing-identity and profile from last command can be used on the following automatic command 

#### Automatic mode command:
```
bash resignipa.sh -i <path/to/ipa> -s "signing-identity" -p "<profile_name>" -d <device_name_or_ecid>
```

#### Automatic mode example:
```
bash resignipa.sh -i ~/kodi.ipa -s "Apple Development: root@gmail.com (T6SL8W599A)" -p "tvOS Team Provisioning Profile: com.xxxx.kodi" -d Livingroom-AppleTV
```

## Credits

- [kambala-decapitator/xcode-auto-signing-assets](https://github.com/kambala-decapitator/xcode-auto-signing-assets)