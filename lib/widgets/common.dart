import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Gradient-header scaffold (original prototype shell).
class JcScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBack;
  final bool showOnline;

  const JcScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showBack = true,
    this.showOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: JC.headerGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 12, 12),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.maybePop(context),
                      )
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ...?actions,
                    if (showOnline) const OnlineChip(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Tappable online/offline pill.
class OnlineChip extends StatelessWidget {
  const OnlineChip({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.read<AppState>().toggleOnline(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.online ? Icons.wifi : Icons.wifi_off, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(s.online ? 'Online' : 'Offline',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class JcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  const JcCard({super.key, required this.child, this.padding, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: JC.card, borderRadius: JC.radius, boxShadow: JC.cardShadow),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

/// Big home-screen action tile (icon + count + label).
class HomeTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? count;
  final VoidCallback? onTap;
  const HomeTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.count,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return JcCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (count != null)
              Text(count!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: JC.ink)),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: JC.ink)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: JC.muted),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: JC.sky, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: JC.ink)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

class PatientAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const PatientAvatar(this.initials, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: JC.sky.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Text(initials, style: TextStyle(color: JC.navy, fontWeight: FontWeight.w700, fontSize: size * 0.4)),
    );
  }
}
