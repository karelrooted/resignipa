# resignipa
resign ipa and install to apple device (iOS, TVOS) using fastlane and cfgutil on MacOS

## usage
interactive mode: choose certificate and profile manully
```
bash <(curl -L -s https://raw.githubusercontent.com/karelrooted/resignipa/main/resignipa.sh) -i <path/to/ipa>
```
automatic mode: can be use for cron auto refresh so sideload app doesn't expire
```
bash <(curl -L -s https://raw.githubusercontent.com/karelrooted/resignipa/main/resignipa.sh) -i <path/to/ipa> -s "signing-identity" -p "<profile_name_or_path>" -d <device_name_or_ecid>
```
automatic mode example:
```
bash <(curl -L -s https://raw.githubusercontent.com/karelrooted/resignipa/main/resignipa.sh) -i ~/kodi.ipa -s "Apple Development: root@gmail.com (T6SL8W599A)" -p "tvOS Team Provisioning Profile: com.xxxx.kodi" -d Livingroom-AppleTV
```
## Todo
* automatic refresh expired profile
