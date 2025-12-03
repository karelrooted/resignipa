#!/bin/bash

############################################################
# Help                                                     #
############################################################
Help() {
    # Display Help
    echo "resigning ipa and install to apple device."
    echo "usage: resignipa.sh -i <ipa file path> [ -s \"<signing-identity>\" -p \"<profile_name_or_path>\" -d device_name_or_ecid -k ] | [-h]"
    echo "options:"
    echo "i     : The path to the original ipa file to be resigned."
    echo "s     : Optional, The identiy/name of the signing certifiate installed in keychain."
    echo "p     : Optional, The name or path to the provisioning profile. ex: \"tvOS Team Provisioning Profile: com.karelrooted.yattee\""
    echo "d     : Optional, Install ipa to device, value can be Device name or ecid."
    echo "k     : Optional, Keep the resign ipa, default: the resign ipa in temp directory will be deleted"
    echo "h     : Optional, Print this Help."
    echo
}

GetProfileName() {
    eval /usr/bin/security cms -D -i "$@" | yq -p xml '.plist.dict.string.1'
}

GetProfileNameAndExpiredDate() {
    eval /usr/bin/security cms -D -i "$@" | yq -p xml '.plist.dict.string.1,.plist.dict.date.1'
}
export -f GetProfileName
export -f GetProfileNameAndExpiredDate

# Get the options
while getopts ":hi:s:p:d:k" option; do
    case $option in
    h)
        Help
        exit
        ;;
    i)
        ipa=$OPTARG
        ;;
    s)
        signing_identity=$OPTARG
        ;;
    p)
        provisioning_profile=$OPTARG
        ;;
    d)
        device=$OPTARG
        ;;
    k)
        keep_ipa=true
        ;;
    \?) # Invalid option
        echo "Error: Invalid option"
        exit
        ;;
    esac
done
if [ ! -f "$ipa" ]; then
    echo "Please enter valid ipa file path."
    exit 1
fi

# the directory of the script
CURRENT_DIR="$(pwd)"
WORK_DIR=$(mktemp -d)
resigned_ipa="$WORK_DIR/resigned.ipa"
# check if tmp dir was created
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
    echo "Could not create temp dir, Please check the permission"
    exit 1
fi

# deletes the temp directory
function cleanup {
    if [[ ! -z $keep_ipa ]]; then
        echo "The resign ipa is in $resigned_ipa"
        exit 0
    fi
    rm -rf "$WORK_DIR"
    #echo "Deleted temp working directory $WORK_DIR"
}

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT

which -s brew
if [[ $? != 0 ]]; then
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew update
brew list fastlane || brew install fastlane || (echo "Please install fastlane and then retry: brew install fastlane." && exit 1)
brew list yq || brew install yq || (echo "Please install yq and then retry: brew install yq." && exit 1)

xcode_profile_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
if [[ -z $provisioning_profile ]]; then
    profiles=$(ls | grep mobileprovision)
    if [ -z "$profiles" ]; then
        profile_dir="$xcode_profile_dir"
    else
        profile_dir="$CURRENT_DIR"
    fi
    profiles_size=$(ls "$profile_dir" | grep mobileprovision | wc -l)
    export profile_dir
    IFS=$'\n' profiles=$(ls "$profile_dir" | grep mobileprovision | xargs -I {} bash -c 'GetProfileName \"${profile_dir}/{}\" ')
    if [ -z "$profiles" ]; then
        echo "Can not find profiles, Use the following kodi tutorial to get the certificate and profile and try again:"
        echo "https://kodi.wiki/view/HOW-TO:Install_Kodi_on_Apple_TV_4_and_5_(HD_and_4K)"
        exit 1
    fi
    if [ $profiles_size -eq 1 ]; then
        selected_profile=${profiles[0]}
    else
        PS3="Please select the profile to sign the app with: "
        select selected_profile in $profiles; do
            break
        done
    fi
    provisioning_profile=$(ls "$profile_dir" | grep mobileprovision | xargs -I {} bash -c 'printf {}" " && GetProfileName \"${profile_dir}/{}\"' | grep "$selected_profile$" | awk '{print $1}')
    provisioning_profile="$profile_dir/$provisioning_profile"
    if [ ! -f "$provisioning_profile" ]; then
        echo "Profile does not exist. Please try again."
        exit 1
    fi
else
    if [ ! -f "$provisioning_profile" ]; then
        bundleID=$(echo $provisioning_profile | awk '{print $NF}')
        if [[ ! -z $bundleID ]]; then
            cd resignipa && xcodebuild -target resignipa PRODUCT_BUNDLE_IDENTIFIER=$bundleID -allowProvisioningUpdates 2>/dev/null | grep --fixed-strings --after-context=2 'Signing Identity:' && cd -
        fi
        profile_dir="$xcode_profile_dir"
        export profile_dir
        provisioning_profile=$(ls "$profile_dir" | grep mobileprovision | xargs -I {} bash -c 'printf {}" " && GetProfileName \"${profile_dir}/{}\"' | grep "$provisioning_profile$" | awk '{print $1}')
        provisioning_profile="$profile_dir/$provisioning_profile"
        if [ ! -f "$provisioning_profile" ]; then
            echo "Profile does not exist. Please try again."
            exit 1
        fi
    fi
fi

shopt -s nocasematch
if [[ $ipa =~ "kodi" ]]; then
    cd $WORK_DIR
    echo "unzip kodi and removing topself plugin, please wait..."
    if [[ $ipa =~ "deb" ]]; then
        tar -xf $ipa
        if [[ $? != 0 ]]; then
            echo "Error: failed to extract deb file. Please check file exist and permission."
            exit 1
        fi
        tar -zxf $WORK_DIR/data.tar.xz
        mv Applications Payload
    else
        unzip -q $ipa -d $WORK_DIR
        if [[ $? != 0 ]]; then
            echo "Error: failed to unzip ipa file. Please check file exist and permission."
            exit 1
        fi
    fi
    rm -fr $WORK_DIR/Payload/Kodi.app/Plugins/kodi-topshelf.appex
    cp "$provisioning_profile" ./Payload/Kodi.app/embedded.mobileprovision
    zip -q -r $resigned_ipa ./Payload
    cd $CURRENT_DIR
else
    cp $ipa $resigned_ipa
fi
if [[ $? != 0 ]]; then
    echo "Error: failed to copy ipa file to temp directory. Please check file exist and permission."
    exit 1
fi
fastlane_cmd="fastlane sigh resign \"$resigned_ipa\" "
if [[ ! -z $signing_identity ]]; then
    fastlane_cmd="$fastlane_cmd --signing_identity \"$signing_identity\" "
fi
fastlane_cmd="$fastlane_cmd --provisioning_profile \"$provisioning_profile\" "
eval "$fastlane_cmd"
if [[ $? != 0 ]]; then
    exit 1
fi
cfgutil="/Applications/Apple Configurator.app/Contents/MacOS/cfgutil"
if [ ! -f "$cfgutil" ]; then
    echo "cfgutil does not exist."
    echo "Please install Apple Configurator from the Mac App Store."
    exit 1
fi
if [[ -z $device ]]; then
    device_list=$("$cfgutil" list | awk -F ': ' '{print $NF}')
    if [ -z "$device_list" ]; then
        echo "Device list empty. Please pair your device in Apple Configurator and try again."
        exit 1
    fi
    PS3="Select a device to install: "
    select device in $device_list; do
        device_ecid=$("$cfgutil" list | grep $device | awk '{print $4}')
        break
    done
else
    device_ecid=$("$cfgutil" list | grep -i $device | awk '{print $4}')
fi
if [[ -z "$device_ecid" ]]; then
    echo "Device not found. Please pair your device in Apple Configurator and try again."
    exit 1
fi
"$cfgutil" -e $device_ecid install-app $resigned_ipa
