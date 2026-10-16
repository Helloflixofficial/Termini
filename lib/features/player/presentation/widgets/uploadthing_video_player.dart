import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_client.dart';

class UploadThingVideoPlayer extends ConsumerStatefulWidget {
  final String? chapterId;
  final String? uploadThingVideoUrl;
  final VoidCallback? onVideoEnd;

  const UploadThingVideoPlayer({
    super.key,
    this.chapterId,
    this.uploadThingVideoUrl,
    this.onVideoEnd,
  });

  @override
  ConsumerState<UploadThingVideoPlayer> createState() =>
      _UploadThingVideoPlayerState();
}

class _UploadThingVideoPlayerState
    extends ConsumerState<UploadThingVideoPlayer> {
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
  void didUpdateWidget(covariant UploadThingVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId ||
        oldWidget.uploadThingVideoUrl != widget.uploadThingVideoUrl) {
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

    // Stream locally cached UploadThing files through the backend byte-range
    // endpoint. Some UploadThing file URLs return 404 for Android range reads.
    final chapterId = widget.chapterId?.trim();
    if (chapterId != null && chapterId.isNotEmpty) {
      final headers = await _videoAuthHeaders();
      final cachedVideoUrl = Uri.parse(
        '${AppEnv.apiBaseUrl}/api/videos/${Uri.encodeComponent(chapterId)}',
      );
      final success = await _tryInitialize(cachedVideoUrl, headers: headers);
      if (success) return;
    }

    // Keep UploadThing as the only remote source and fallback for uncached
    // videos. No Mux playback request is made by the phone app.
    final uploadedVideoUrl = widget.uploadThingVideoUrl?.trim();
    if (uploadedVideoUrl != null && uploadedVideoUrl.isNotEmpty) {
      final success = await _tryInitialize(Uri.parse(uploadedVideoUrl));
      if (success) return;
    }

    // Both stored video sources failed or are unavailable.
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = 'UploadThing video could not be loaded.';
      });
    }
  }

  Future<Map<String, String>> _videoAuthHeaders() async {
    final storage = ref.read(secureStorageProvider);
    final headers = <String, String>{};
    final token = await storage.read(key: 'auth_session_token');
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final userData = await storage.read(key: 'auth_user_data');
    if (userData != null) {
      try {
        final userId =
            (jsonDecode(userData) as Map<String, dynamic>)['id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          headers['X-User-Id'] = userId;
        }
      } catch (_) {}
    }
    return headers;
  }

  Future<bool> _tryInitialize(
    Uri url, {
    Map<String, String> headers = const {},
  }) async {
    VideoPlayerController? controller;
    try {
      _disposePlayer();

      final activeController = VideoPlayerController.networkUrl(
        url,
        httpHeaders: headers,
      );
      controller = activeController;

      await activeController.initialize();

      activeController.addListener(() {
        if (_videoPlayerController != null &&
            _videoPlayerController!.value.isInitialized &&
            _videoPlayerController!.value.position >=
                _videoPlayerController!.value.duration &&
            _videoPlayerController!.value.duration > Duration.zero) {
          widget.onVideoEnd?.call();
        }
      });

      final chewie = ChewieController(
        videoPlayerController: activeController,
        autoPlay: true,
        looping: false,
        aspectRatio: activeController.value.aspectRatio > 0
            ? activeController.value.aspectRatio
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
          _videoPlayerController = activeController;
          _chewieController = chewie;
          _isLoading = false;
          _isError = false;
        });
      }
      return true;
    } catch (e) {
      await controller?.dispose();
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
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.amberAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'Video Playback Unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
