#!/bin/bash
#
# Build a Signal package for Android

set -euxo pipefail

test -d Signal-Android           # assume Signal code is checked out
test -v 1                        # expect first argument to be the version
test ! -d ${1}                   # exit if dir exists / we've built it previously
test -f my-release-key.keystore  # see Makefile to generate a signing key
SIGNAL_TAG="${1}"

# different versions need slightly different patches
v=$(echo $SIGNAL_TAG | tr -d '.v')

if [ "$v" -gt 6228 ]; then
  patch="patch-001-forced-upgrades-6.23.0.diff patch-002-enable-sms-6.19.0.diff"
elif [ "$v" -gt 6199 ]; then
  patch="patch-001-forced-upgrades-6.20.0.diff patch-002-enable-sms-6.19.0.diff"
elif [ "$v" -gt 6189 ]; then
  patch="patch-001-forced-upgrades-6.14.4.diff patch-002-enable-sms-6.19.0.diff"
elif [ "$v" -gt 6144 ]; then
  patch="patch-001-forced-upgrades-6.14.4.diff patch-002-enable-sms-6.15.3.diff"
elif [ "$v" -gt 6139 ]; then
  patch="patch-001-forced-upgrades-6.14.4.diff patch-002-enable-sms-6.13.8.diff"
elif [ "$v" -gt 6136 ]; then
  patch="patch-001-forced-upgrades-6.9.0.diff patch-002-enable-sms-6.13.8.diff"
elif [ "$v" -gt 6110 ]; then
  patch="patch-001-forced-upgrades-6.9.0.diff patch-002-enable-sms-6.11.1.diff"
elif [ "$v" -gt 689 ]; then
  patch="patch-001-forced-upgrades-6.9.0.diff patch-002-enable-sms-6.9.0.diff"
elif [ "$v" -gt 680 ]; then
  patch="patch-001-forced-upgrades-6.8.1.diff patch-002-enable-sms-6.8.1.diff"
else
  patch="patch-001-forced-upgrades-6.5.0.diff patch-002-enable-sms-6.5.0.diff"
fi

echo "Beginning: ${SIGNAL_TAG}"
cd Signal-Android
git reset --hard
git checkout main
git checkout ${SIGNAL_TAG}
for p in $patch; do
  git apply ../$p
done
(cd reproducible-builds && docker build -t signal-android:${SIGNAL_TAG} .)
docker run --rm -v $(pwd):/project -w /project signal-android:${SIGNAL_TAG} bash -c 'git config --global --add safe.directory /project && ./gradlew clean assemblePlayProdRelease'

mkdir -p ../${SIGNAL_TAG}
find ./app/build/outputs/ -name "*.apk" -exec cp {} ../${SIGNAL_TAG}/ \;
docker run --rm -v $(pwd):/project -w /project signal-android:${SIGNAL_TAG} rm -rf /project/app/build/outputs/ || true

# Sign the apks (android won't let you install them otherwise)
for i in ../${SIGNAL_TAG}/*.apk; do
  apksigner sign --ks ../my-release-key.keystore --ks-pass "pass:testtest" ${i}
done

echo -e "\n\nSee the ${SIGNAL_TAG}/ folder for the APK files"
