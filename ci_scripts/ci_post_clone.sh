#!/bin/sh
# Auto-increment build number for Xcode Cloud
BUILD_NUMBER=$(date +%Y%m%d%H%M)
cd $CI_WORKSPACE
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" CardWise.xcodeproj/project.pbxproj
echo "Build number set to $BUILD_NUMBER"
