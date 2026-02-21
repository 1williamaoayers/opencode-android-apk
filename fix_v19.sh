#!/bin/bash
gh workflow run build-apk.yml --ref v0.0.19
sleep 10
RUN_ID=$(gh run list -b master -w "Build Android APK" -L 1 --json databaseId -q '.[0].databaseId')
echo "Waiting for run $RUN_ID to finish..."
gh run watch $RUN_ID
echo "Run completed. Downloading from v0.0.20..."
gh release download v0.0.20 -p "*.apk" || { echo "Download failed"; exit 1; }
echo "Uploading to v0.0.19..."
gh release upload v0.0.19 app-release.apk --clobber
echo "Cleaning up v0.0.20..."
gh release delete v0.0.20 -y --cleanup-tag || true
git push --delete origin v0.0.20 || true
echo "Restore complete!"
