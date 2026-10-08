// Desktop wallpaper that rotates through a folder of pictures.
//
// Shows the bundled FALLEN SOLDIER picture at once, then fades to a random
// picture from the folder (see WallpaperRotationService) and fades to another
// one every interval. Each picture is decoded off-screen first, so a large PNG
// never makes the swap stutter, and one that fails to decode is dropped from
// the rotation rather than shown broken. If the folder is missing or empty the
// bundled picture simply stays.
//
// The CPU-driven aura lives in CpuAuraWallpaper; the bolt glows are switched on
// only while FALLEN SOLDIER is showing. Over every picture sits the same
// burning blunt and rising smoke as garden mode (GardenSmoke), part of the
// wallpaper layer so it stays behind icons and windows and never takes a click.

import 'dart:async';
import 'dart:io' hide Platform;
import 'package:flutter/material.dart';
import '../services/wallpaper_rotation_service.dart';
import 'cpu_aura_wallpaper.dart';
import 'garden_smoke.dart';

class RotatingWallpaper extends StatefulWidget {
  const RotatingWallpaper({super.key, this.folder, this.interval, this.blunt});

  /// Overrides the default folder (used by tests).
  final String? folder;

  /// Overrides the swap interval (used by tests).
  final Duration? interval;

  /// Overrides whether the blunt and smoke show (default: SWARM_WALLPAPER_BLUNT,
  /// on unless set to 0).
  final bool? blunt;

  @override
  State<RotatingWallpaper> createState() => _RotatingWallpaperState();
}

class _RotatingWallpaperState extends State<RotatingWallpaper> {
  final _picker = WallpaperPicker();
  Timer? _timer;
  bool _busy = false;

  // null means the bundled picture.
  ImageProvider? _image;
  bool _boltGlows = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      widget.interval ?? WallpaperRotationService.interval,
      (_) => _advance(),
    );
    // Needs a context for the screen size, so wait for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Decode at screen width, not file size: some pictures are 2816 px wide and
  /// there is no point holding more pixels than the display can show.
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
      final folder = widget.folder ?? WallpaperRotationService.dir;
      // A few tries, so one corrupt file doesn't cost a whole interval.
      for (var attempt = 0; attempt < 3; attempt++) {
        final pool = await WallpaperRotationService.listImages(folder);
        if (!mounted) return;
        final next = _picker.next(pool);
        if (next == null) {
          // Folder gone (drive unmounted): go back to the bundled picture.
          if (_image != null) {
            setState(() {
              _image = null;
              _boltGlows = true;
            });
          }
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
        setState(() {
          _image = provider;
          _boltGlows = WallpaperRotationService.isFallenSoldier(next);
        });
        return;
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      CpuAuraWallpaper(
        image: _image ?? const AssetImage(kFallenSoldierWallpaper),
        boltGlows: _boltGlows,
      ),
      if (widget.blunt ?? WallpaperRotationService.blunt) const GardenSmoke(),
    ]);
  }
}
