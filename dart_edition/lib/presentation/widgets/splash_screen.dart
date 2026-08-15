import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";

/// Startup screen shown while local preferences are restored.
///
/// The layout intentionally keeps the desktop composition at the 3:2 ratio
/// from the design reference, while [SplachScreen] uses a vertical mobile
/// composition.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    return _isDesktop ? const SplashWindow() : const SplachScreen();
  }
}

/// Desktop splash window based on the 540 × 360 composition.
class SplashWindow extends StatelessWidget {
  const SplashWindow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Material(
        color: colors.surface,
        child: Center(
          child: AspectRatio(
            aspectRatio: 1.5,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 900, maxHeight: 600),
              child: _DesktopSplashLayout(),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSplashLayout extends StatelessWidget {
  const _DesktopSplashLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 120, child: _DesktopAccentPanel()),
        Expanded(
          child: _SplashCanvas(
            contentPadding: const EdgeInsets.fromLTRB(18, 16, 22, 24),
            child: const _SplashContent(compact: false),
          ),
        ),
      ],
    );
  }
}

class _DesktopAccentPanel extends StatelessWidget {
  const _DesktopAccentPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key("desktop-splash-decoration"),
      color: colors.primaryContainer,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: IgnorePointer(
                child: SvgPicture.asset(
                  "assets/images/splash_decoration.svg",
                  width: 120,
                  height: 360,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashCanvas extends StatelessWidget {
  const _SplashCanvas({required this.contentPadding, required this.child});

  final EdgeInsets contentPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(padding: contentPadding, child: child),
      ),
    );
  }
}

/// Mobile splash screen. The name follows the requested `SplachScreen` API.
class SplachScreen extends StatelessWidget {
  const SplachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _SplashCanvas(
        contentPadding: EdgeInsets.fromLTRB(32, 48, 32, 32),
        child: _SplashContent(compact: true),
      ),
    );
  }
}

/// Correctly-spelled alias for callers that prefer it.
class SplashScreen extends SplachScreen {
  const SplashScreen({super.key});
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: colors.onSurface,
      fontSize: compact ? 30 : 24,
      fontWeight: FontWeight.w500,
      height: 1.15,
    );
    final codeNameStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: colors.onSurface,
      fontSize: compact ? 18 : 16,
      height: 1.35,
    );
    final detailStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 12,
      height: 1.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AppIcon(),
        SizedBox(height: compact ? 22 : 12),
        Text("物語 Assistant", style: titleStyle),
        const SizedBox(height: 2),
        Text("Codename Hana", style: codeNameStyle),
        const SizedBox(height: 7),
        Text("Version 0.9.19    Build 919", style: detailStyle),
        const Spacer(),
        Text("2025–2026 Heyairu(TM)", style: detailStyle),
      ],
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        "assets/icon/app_icon.png",
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.auto_stories_rounded,
          color: colors.onSecondaryContainer,
          size: 32,
        ),
      ),
    );
  }
}
