# iOS launch image

This asset set contains the 1x, 2x and 3x `LaunchImage` variants referenced by `Contents.json`
and `ios/Runner/Base.lproj/LaunchScreen.storyboard`.

When replacing the native image, keep all three scales consistent with the night background and
the [Histae design system](../../../../DESIGN_SYSTEM.md). On macOS, open `ios/Runner.xcworkspace`
in Xcode and inspect both the asset set and launch storyboard.

The animated wordmark/book presentation is separate, in
[app_opening.dart](../../../../lib/app/app_opening.dart). Verify a real iOS cold start after changing
native launch assets; a Flutter widget preview does not validate the native launch screen.
