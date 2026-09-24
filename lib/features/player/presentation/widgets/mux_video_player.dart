import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/config/env.dart';

class MuxVideoPlayer extends StatefulWidget {
  final String? chapterId;
  final String? playbackId;
  final String? fallbackVideoUrl;
  final VoidCallback? onVideoEnd;

  const MuxVideoPlayer({
    super.key,
    this.chapterId,
    this.playbackId,
    this.fallbackVideoUrl,
    this.onVideoEnd,
  });

  @override
  State<MuxVideoPlayer> createState() => _MuxVideoPlayerState();
}

class _MuxVideoPlayerState extends State<MuxVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _isError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant MuxVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId ||
        oldWidget.playbackId != widget.playbackId ||
        oldWidget.fallbackVideoUrl != widget.fallbackVideoUrl) {
      _disposePlayer();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = null;
    });

    // 1. Try local backend stream (adb reverse 127.0.0.1:3000)
    if (widget.chapterId != null && widget.chapterId!.trim().isNotEmpty) {
      final chId = widget.chapterId!.trim();
      final localUrl = '${AppEnv.apiBaseUrl}/api/videos/$chId';
      final success = await _tryInitialize(localUrl);
      if (success) return;

      // 1b. Try direct Wi-Fi IP fallback (192.168.1.12:3000)
      final wifiUrl = 'http://192.168.1.12:3000/api/videos/$chId';
      final wifiSuccess = await _tryInitialize(wifiUrl);
      if (wifiSuccess) return;
    }

    // 2. Try Mux stream if playbackId is provided
    if (widget.playbackId != null && widget.playbackId!.trim().isNotEmpty) {
      final muxUrl = 'https://stream.mux.com/${widget.playbackId!.trim()}.m3u8';
      final success = await _tryInitialize(muxUrl);
      if (success) return;
    }

    // 3. If local stream and Mux failed, try fallbackVideoUrl (from DB / Uploadthing)
    if (widget.fallbackVideoUrl != null && widget.fallbackVideoUrl!.trim().isNotEmpty) {
      final fallbackUrl = widget.fallbackVideoUrl!.trim();
      final success = await _tryInitialize(fallbackUrl);
      if (success) return;
    }

    // 4. All sources failed or no video available
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = 'Video stream could not be loaded.';
      });
    }
  }

  Future<bool> _tryInitialize(String url) async {
    try {
      _disposePlayer();

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      await controller.initialize();

      controller.addListener(() {
        if (_videoPlayerController != null &&
            _videoPlayerController!.value.isInitialized &&
            _videoPlayerController!.value.position >=
                _videoPlayerController!.value.duration &&
            _videoPlayerController!.value.duration > Duration.zero) {
          widget.onVideoEnd?.call();
        }
      });

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF0284C7),
          handleColor: const Color(0xFF0284C7),
          backgroundColor: Colors.grey[700]!,
          bufferedColor: Colors.grey[500]!,
        ),
      );

      if (mounted) {
        setState(() {
          _videoPlayerController = controller;
          _chewieController = chewie;
          _isLoading = false;
          _isError = false;
        });
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _disposePlayer() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 240,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
      );
    }

    if (_isError) {
      return Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.amberAccent, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Video Playback Unavailable',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage ?? 'Unable to connect to video stream',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _initializePlayer,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Playback'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio > 0
            ? _videoPlayerController!.value.aspectRatio
            : 16 / 9,
        child: Chewie(controller: _chewieController!),
      );
    }

    return Container(
      height: 240,
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF0284C7)),
      ),
    );
  }
}
