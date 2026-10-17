// Full-screen photo background for garden mode.
//
// Cycles through the garden's photos in a random no-repeat order, crossfading
// from one to the next with a slow zoom on top so a still photo isn't dead.
// Every picture is decoded off-screen first and a file that fails to decode is
// dropped from the rotation. The folder is re-read on each change, so photos
// added while the garden is open join in.
//
// Reports each photo as it appears through [onChanged] (null when there is
// nothing to show), so the screen can put the right strain label on it. While
// there is nothing to show this paints nothing and the screen's own scene
// shows through.

import 'dart:async';
import 'dart:io' hide Platform;
import 'package:flutter/material.dart';
import '../services/garden_backgrounds_service.dart';
import '../services/wallpaper_rotation_service.dart' show WallpaperPicker;
import 'crossfade_image.dart';

class GardenBackdrop extends StatefulWidget {
  const GardenBackdrop({
    super.key,
    required this.loader,
    required this.interval,
    required this.onChanged,
  });

  /// Returns the photos to rotate through; called again on every change.
  final Future<List<GardenBackground>> Function() loader;
  final Duration interval;
  final ValueChanged<GardenBackground?> onChanged;

  @override
  State<GardenBackdrop> createState() => _GardenBackdropState();
}

class _GardenBackdropState extends State<GardenBackdrop> with SingleTickerProviderStateMixin {
  final _picker = WallpaperPicker();
  late final AnimationController _zoom;
  Timer? _timer;
  bool _busy = false;
  ImageProvider? _image;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(vsync: this, duration: const Duration(seconds: 26))
      ..repeat(reverse: true);
    _timer = Timer.periodic(widget.interval, (_) => _advance());
    // Needs a context for the screen size, so wait for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _zoom.dispose();
    super.dispose();
  }

  ImageProvider _providerFor(String path) {
    final screen = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = (screen.width * dpr).round().clamp(1, 3840);
    return ResizeImage.resizeIfNeeded(width, null, FileImage(File(path)));
  }

  Future<void> _advance() async {
    if (_busy) return;
    _busy = true;
    try {
      // A few tries, so one corrupt file doesn't cost a whole interval.
      for (var attempt = 0; attempt < 3; attempt++) {
        final all = await widget.loader();
        if (!mounted) return;
        final byPath = {for (final b in all) b.path: b};
        final next = _picker.next(byPath.keys.toList());
        if (next == null) {
          if (_image != null) setState(() => _image = null);
          widget.onChanged(null);
          return;
        }
        final provider = _providerFor(next);
        var failed = false;
        await precacheImage(provider, context, onError: (_, __) => failed = true);
        if (!mounted) return;
        if (failed) {
          _picker.reject(next);
          continue;
        }
        setState(() => _image = provider);
        widget.onChanged(byPath[next]);
        return;
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.expand();
    return Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(
        animation: _zoom,
        builder: (_, child) => Transform.scale(
          scale: 1.0 + 0.07 * Curves.easeInOut.transform(_zoom.value),
          child: child,
        ),
        child: CrossfadeImage(
          image: image,
          duration: const Duration(milliseconds: 1400),
          // Dim a little so the label and smoke stay readable over bright photos.
          color: Colors.black.withValues(alpha: 0.12),
          colorBlendMode: BlendMode.darken,
        ),
      ),
      // Darker toward the bottom, where the label and the blunts sit.
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.38)],
            stops: const [0.60, 1.0],
          ),
        ),
      ),
    ]);
  }
}
