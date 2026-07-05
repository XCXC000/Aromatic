import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final bool glow;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final deco = glow
        ? AromaticTheme.glassGlowDecoration(brightness)
        : AromaticTheme.glassDecoration(brightness);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: margin ?? const EdgeInsets.only(bottom: AromaticTheme.spaceSM),
        padding: padding ?? const EdgeInsets.all(AromaticTheme.spaceMD),
        decoration: deco,
        child: child,
      ),
    );
  }
}

class ExpandableGlassCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget expandedContent;
  final bool initiallyExpanded;
  final Color? accentColor;

  const ExpandableGlassCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.expandedContent,
    this.initiallyExpanded = false,
    this.accentColor,
  });

  @override
  State<ExpandableGlassCard> createState() => _ExpandableGlassCardState();
}

class _ExpandableGlassCardState extends State<ExpandableGlassCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (_expanded) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AromaticTheme.of(context);
    final color = widget.accentColor ?? colors.accent;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: AromaticTheme.spaceSM),
        decoration: _expanded
            ? AromaticTheme.glassGlowDecoration(Theme.of(context).brightness)
            : AromaticTheme.glassDecoration(Theme.of(context).brightness),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AromaticTheme.spaceMD),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AromaticTheme.spaceSM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AromaticTheme.spaceMD, 0,
                  AromaticTheme.spaceMD, AromaticTheme.spaceMD,
                ),
                child: widget.expandedContent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
