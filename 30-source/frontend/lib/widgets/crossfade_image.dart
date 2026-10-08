// Fills its box with [image] and, when [image] changes, fades the new picture
// in over the old one. The old picture stays fully opaque underneath until the
// fade ends, so the screen never dips toward the background colour mid-swap
// (which two simultaneous fades, as in AnimatedSwitcher, would cause).

import 'package:flutter/material.dart';

class CrossfadeImage extends StatefulWidget {
  const CrossfadeImage({
    super.key,
    required this.image,
    this.duration = const Duration(milliseconds: 1500),
    this.fit = BoxFit.cover,
    this.color,
    this.colorBlendMode,
  });

  final ImageProvider image;
  final Duration duration;
  final BoxFit fit;
  final Color? color;
  final BlendMode? colorBlendMode;

  @override
  State<CrossfadeImage> createState() => _CrossfadeImageState();
}

class _CrossfadeImageState extends State<CrossfadeImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  ImageProvider? _previous;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: widget.duration, value: 1)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _previous != null && mounted) {
          setState(() => _previous = null);
        }
      });
  }

  @override
  void didUpdateWidget(CrossfadeImage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _previous = old.image;
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Widget _picture(ImageProvider provider, Key key) => Image(
        key: key,
        image: provider,
        fit: widget.fit,
        alignment: Alignment.center,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        gaplessPlayback: true,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      if (_previous != null) _picture(_previous!, const ValueKey('previous')),
      FadeTransition(
        key: const ValueKey('current'),
        opacity: _fade,
        child: _picture(widget.image, const ValueKey('current-picture')),
      ),
    ]);
  }
}
