import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../theme/swarm_text_styles.dart';

class VideoItem {
  final String title;
  final String path;
  final bool isUrl;
  final String? fileSize;
  final String? duration;
  final String? prompt;

  const VideoItem({
    required this.title,
    required this.path,
    this.isUrl = false,
    this.fileSize,
    this.duration,
    this.prompt,
  });
}

class CinemaPage extends StatefulWidget {
  final String? initialVideoPath;

  const CinemaPage({super.key, this.initialVideoPath});

  @override
  State<CinemaPage> createState() => _CinemaPageState();
}

class _CinemaPageState extends State<CinemaPage> with SingleTickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoController;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100.0;
  double _playbackRate = 1.0;
  bool _isLooping = true;
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playSub;
  StreamSubscription? _volSub;

  final List<VideoItem> _videoLibrary = [];
  VideoItem? _activeVideo;
  bool _isScanning = false;

  final TextEditingController _urlController = TextEditingController();

  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _purple = Color(0xFFD500F9);
  static const Color _green = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);

    _initPlayerListeners();
    _scanForVideos();

    if (widget.initialVideoPath != null) {
      _loadVideo(VideoItem(title: widget.initialVideoPath!.split('/').last, path: widget.initialVideoPath!));
    }
  }

  void _initPlayerListeners() {
    _posSub = _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _durSub = _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _playSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _volSub = _player.stream.volume.listen((vol) {
      if (mounted) setState(() => _volume = vol);
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _volSub?.cancel();
    _player.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _scanForVideos() async {
    setState(() => _isScanning = true);
    final discovered = <VideoItem>[];

    // 1. Check known primary video locations
    final primaryCandidates = [
      '/run/media/i30ltz/lucy-master/transam_video.mp4',
      '/run/media/i30ltz/lucy-master/Luccile-v+/frontend/assets/splash/lucille_transam_splash.mp4',
      '/run/media/i30ltz/lucy-master/Lucille-v6/frontend/assets/splash/lucille_transam_splash.mp4',
    ];

    for (final p in primaryCandidates) {
      final file = File(p);
      if (file.existsSync()) {
        final sizeMb = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
        discovered.add(VideoItem(
          title: file.path.split('/').last,
          path: file.path,
          fileSize: '$sizeMb MB',
          prompt: p.contains('transam') ? '1999 Trans-Am WS6 burnout & cyber-wasp nest macro 3D' : null,
        ));
      }
    }

    // 2. Scan standard user Video & Downloads folders
    final home = Platform.environment['HOME'] ?? '/home/i30ltz';
    final searchDirs = [
      Directory('$home/Videos'),
      Directory('$home/Downloads'),
    ];

    for (final dir in searchDirs) {
      if (dir.existsSync()) {
        try {
          final entries = dir.listSync(recursive: false);
          for (final entry in entries) {
            if (entry is File) {
              final ext = entry.path.split('.').last.toLowerCase();
              if (['mp4', 'webm', 'mkv', 'mov', 'avi'].contains(ext)) {
                final sizeMb = (entry.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
                discovered.add(VideoItem(
                  title: entry.path.split('/').last,
                  path: entry.path,
                  fileSize: '$sizeMb MB',
                ));
              }
            }
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _videoLibrary.clear();
        _videoLibrary.addAll(discovered);
        _isScanning = false;
        if (_activeVideo == null && _videoLibrary.isNotEmpty) {
          _loadVideo(_videoLibrary.first);
        }
      });
    }
  }

  Future<void> _loadVideo(VideoItem item) async {
    setState(() => _activeVideo = item);
    await _player.open(Media(item.path), play: true);
    await _player.setPlaylistMode(_isLooping ? PlaylistMode.single : PlaylistMode.none);
    await _player.setRate(_playbackRate);
    _startHideControlsTimer();
  }

  Future<void> _pickLocalFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'webm', 'mkv', 'mov', 'avi', 'flv'],
    );

    if (result != null && result.path != null) {
      final path = result.path!;
      final file = File(path);
      final sizeMb = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
      final item = VideoItem(
        title: result.name,
        path: path,
        fileSize: '$sizeMb MB',
      );

      setState(() {
        _videoLibrary.insert(0, item);
      });
      _loadVideo(item);
    }
  }

  void _openUrlDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F141F),
        title: Row(
          children: [
            const Icon(Icons.link, color: _cyan),
            const SizedBox(width: 8),
            Text('STREAM VIDEO URL', style: SwarmTextStyles.title.copyWith(fontSize: 14)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter an HTTP/HTTPS stream link, OpenRouter Grok video output, or CDN URL:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://openrouter.ai/api/v1/videos/.../content',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _cyan, foregroundColor: Colors.black),
            onPressed: () {
              final url = _urlController.text.trim();
              if (url.isNotEmpty) {
                final item = VideoItem(title: 'Stream: ${url.split('/').last}', path: url, isUrl: true);
                setState(() => _videoLibrary.insert(0, item));
                _loadVideo(item);
                Navigator.pop(ctx);
              }
            },
            child: const Text('STREAM NOW'),
          ),
        ],
      ),
    );
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04060A),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              _player.playOrPause();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _player.seek(_position + const Duration(seconds: 5));
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _player.seek(_position - const Duration(seconds: 5));
            } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
              setState(() => _isFullscreen = !_isFullscreen);
            }
          }
        },
        child: Row(
          children: [
            // Left: Video Player Viewport
            Expanded(
              flex: 7,
              child: MouseRegion(
                onHover: (_) {
                  setState(() => _showControls = true);
                  _startHideControlsTimer();
                },
                child: Stack(
                  children: [
                    // Video Surface
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Video(
                          controller: _videoController,
                          controls: (_) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    // Top Bar Overlay
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _cyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.movie_filter_rounded, color: _cyan, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _activeVideo?.title ?? 'SWARM CINEMA STUDIO',
                                    style: SwarmTextStyles.title.copyWith(fontSize: 15, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_activeVideo?.prompt != null)
                                    Text(
                                      _activeVideo!.prompt!,
                                      style: const TextStyle(color: _purple, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.file_open, color: _cyan),
                              tooltip: 'Open Local Video File',
                              onPressed: _pickLocalFile,
                            ),
                            IconButton(
                              icon: const Icon(Icons.link, color: _cyan),
                              tooltip: 'Stream Video URL',
                              onPressed: _openUrlDialog,
                            ),
                            IconButton(
                              icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white70),
                              tooltip: 'Toggle Fullscreen',
                              onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Cyber Transport Controls Overlay
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xF0000000), Colors.transparent],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Scrubber Slider
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: _cyan,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: _cyan,
                                  overlayColor: _cyan.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                  value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1).toDouble(),
                                  onChanged: (val) {
                                    _player.seek(Duration(milliseconds: val.toInt()));
                                  },
                                ),
                              ),

                              // Playback transport buttons
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 36, color: _cyan),
                                    onPressed: () => _player.playOrPause(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.replay_5, color: Colors.white70),
                                    tooltip: 'Back 5s',
                                    onPressed: () => _player.seek(_position - const Duration(seconds: 5)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.forward_5, color: Colors.white70),
                                    tooltip: 'Forward 5s',
                                    onPressed: () => _player.seek(_position + const Duration(seconds: 5)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                  const Spacer(),
                                  // Playback Rate Selector
                                  PopupMenuButton<double>(
                                    tooltip: 'Playback Speed',
                                    initialValue: _playbackRate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('${_playbackRate}x', style: const TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    itemBuilder: (ctx) => [0.5, 1.0, 1.25, 1.5, 2.0].map((rate) {
                                      return PopupMenuItem(value: rate, child: Text('${rate}x'));
                                    }).toList(),
                                    onSelected: (rate) {
                                      setState(() => _playbackRate = rate);
                                      _player.setRate(rate);
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  // Loop Toggle
                                  IconButton(
                                    icon: Icon(Icons.repeat, color: _isLooping ? _green : Colors.white38),
                                    tooltip: _isLooping ? 'Looping Active' : 'Loop Disabled',
                                    onPressed: () {
                                      setState(() => _isLooping = !_isLooping);
                                      _player.setPlaylistMode(_isLooping ? PlaylistMode.single : PlaylistMode.none);
                                    },
                                  ),
                                  // Volume
                                  IconButton(
                                    icon: Icon(_isMuted || _volume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white70),
                                    onPressed: () {
                                      setState(() => _isMuted = !_isMuted);
                                      _player.setVolume(_isMuted ? 0.0 : _volume);
                                    },
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: SliderTheme(
                                      data: const SliderThemeData(
                                        trackHeight: 3,
                                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4),
                                        activeTrackColor: Colors.white70,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                      ),
                                      child: Slider(
                                        min: 0.0,
                                        max: 100.0,
                                        value: _isMuted ? 0.0 : _volume,
                                        onChanged: (val) {
                                          setState(() {
                                            _volume = val;
                                            _isMuted = false;
                                          });
                                          _player.setVolume(val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right: Video Library & AI Studio Gallery
            if (!_isFullscreen)
              Expanded(
                flex: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A0D14),
                    border: Border(left: BorderSide(color: Color(0xFF1E2838))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(Icons.video_library, color: _cyan, size: 18),
                            const SizedBox(width: 8),
                            Text('PRODUCTIONS & LIBRARY', style: SwarmTextStyles.title.copyWith(fontSize: 13)),
                            const Spacer(),
                            IconButton(
                              icon: _isScanning
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _cyan))
                                  : const Icon(Icons.refresh, size: 18, color: Colors.white60),
                              tooltip: 'Refresh Videos',
                              onPressed: _scanForVideos,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF1E2838)),

                      // Video List
                      Expanded(
                        child: _videoLibrary.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.smart_display_outlined, size: 48, color: Colors.white24),
                                      const SizedBox(height: 12),
                                      const Text('No videos found in library.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _pickLocalFile,
                                        icon: const Icon(Icons.file_open, size: 16),
                                        label: const Text('Open Video File'),
                                        style: ElevatedButton.styleFrom(backgroundColor: _cyan, foregroundColor: Colors.black),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _videoLibrary.length,
                                itemBuilder: (context, index) {
                                  final item = _videoLibrary[index];
                                  final isSelected = _activeVideo?.path == item.path;

                                  return GestureDetector(
                                    onTap: () => _loadVideo(item),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? _cyan.withValues(alpha: 0.12) : const Color(0xFF0F141F),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? _cyan : const Color(0xFF1E2838),
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isSelected ? _cyan : Colors.white12),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                item.isUrl ? Icons.cloud : Icons.movie,
                                                color: isSelected ? _cyan : Colors.white60,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    color: isSelected ? _cyan : Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  item.fileSize ?? 'Streamable',
                                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(Icons.play_arrow, color: _cyan, size: 20),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Quick action buttons at bottom
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickLocalFile,
                                icon: const Icon(Icons.folder_open, size: 16, color: _cyan),
                                label: const Text('Open File', style: TextStyle(color: _cyan, fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _cyan),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openUrlDialog,
                                icon: const Icon(Icons.link, size: 16),
                                label: const Text('Stream URL', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
