# Store Readiness Checklist

## Ready for Private Testing

- macOS DMG, Android TV ARM64 APK, and Web archive build reproducibly.
- TV launcher assets, app icons, adaptive layouts, and remote-focus foundations are present.
- Playlist credentials stay in platform secure storage and sensitive diagnostics are sanitized.
- Store-facing product copy avoids bundled-content or provider-partnership claims.

## Required Before Public Submission

- Configure protected production signing, Apple notarization, and Store distribution certificates.
- Publish privacy, support, and terms pages at stable HTTPS URLs.
- Capture platform-specific screenshots using authorized demo content only.
- Complete accessibility, remote-control, codec, network-recovery, and physical-device test matrices.
- Perform final legal, metadata-provider attribution, and privacy reviews.

## Platform Notes

- Android TV requires a production keystore and Play Console app signing; the private-test APK uses debug signing.
- macOS distribution requires Developer ID signing and notarization; the private-test DMG is ad-hoc signed.
- iOS and tvOS require App Store Connect records, provisioning, privacy declarations, and device validation.
- Web hosting must enforce HTTPS. GitHub Pages availability depends on the repository visibility and account plan.
