# Spreed.ME iOS app
Spreed.ME is a messaging app that lets you securely send and receive messages and files and even start encrypted video and audiocalls - one-on-one or as conference.

This project is based on a [fork](https://github.com/strukturag/webrtc-ios) of Google's [WebRTC](https://chromium.googlesource.com/external/webrtc) library.

You can use Spreed.ME iOS app with:
- [Spreed.ME service](https://www.spreed.me)
- [Spreedbox](https://www.spreed.me/spreedbox/)
- Spreed.ME app for [Nextcloud](https://apps.nextcloud.com/apps/spreedme)/[ownCloud](https://apps.owncloud.com/content/show.php/Spreed.ME?content=174436)
- Your own Spreed.ME [service](https://github.com/strukturag/spreed-webrtc)

## Prerequisites

- [Install Chromium depot tools.](http://dev.chromium.org/developers/how-tos/install-depot-tools)

## Build steps
Follow these steps to build WebRTC and create fat libraries needed for the XCode project.

```
$ cd third_party
$ gclient sync
$ cd webrtc
$ ./make-webrtc.sh
```

After above steps are completed, you have everything you need to build and run the XCode project.

- Open SpreedME.xcodeproj
- Set valid Provisioning Profiles
- Add a new Scheme using provided Targets (SpreedMe or WebRTC)
- Build & Run created Scheme :smiley:


## App Store
Using this project you will be able to build the following apps that are in the App Store.

- [SpreedME](https://itunes.apple.com/us/app/spreed.me/id1058498417?mt=8)
- [WebRTC](https://itunes.apple.com/us/app/webrtc/id828333357?mt=8)
