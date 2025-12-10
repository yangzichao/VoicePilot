#!/bin/bash
set -e

# Export Mac App Store Package
# This script exports the archive to a .pkg file for App Store submission

ARCHIVE_PATH="./build/HoAh-MAS.xcarchive"
EXPORT_PATH="./build/MAS-Export"
EXPORT_OPTIONS="./scripts/packaging/ExportOptions-MAS.plist"

echo "========================================="
echo "Exporting Mac App Store Package"
echo "========================================="

# Check if archive exists
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "Error: Archive not found at $ARCHIVE_PATH"
    echo "Run 'make archive-mas' first"
    exit 1
fi

# Clean previous export
rm -rf "$EXPORT_PATH"

# Export archive
echo "Exporting archive..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

echo "========================================="
echo "Export completed successfully!"
echo "Package location: $EXPORT_PATH/HoAh.pkg"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Validate: xcrun altool --validate-app -f $EXPORT_PATH/HoAh.pkg -t macos -u YOUR_APPLE_ID"
echo "2. Upload: xcrun altool --upload-app -f $EXPORT_PATH/HoAh.pkg -t macos -u YOUR_APPLE_ID"
echo "3. Or use Transporter app"
