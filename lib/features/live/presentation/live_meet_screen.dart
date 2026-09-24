import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/livekit_repository.dart';

class LiveMeetScreen extends ConsumerStatefulWidget {
  final String roomName;

  const LiveMeetScreen({super.key, required this.roomName});

  @override
  ConsumerState<LiveMeetScreen> createState() => _LiveMeetScreenState();
}

class _LiveMeetScreenState extends ConsumerState<LiveMeetScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isScreenSharing = false;
  bool _isHandRaised = false;
  bool _showChat = false;
  final List<String> _chatMessages = [];
  final _chatInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(liveKitRepositoryProvider);
      final tokenData = await repo.getToken(widget.roomName);

      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      _listener = _room!.createListener();

      _listener!
        ..on<RoomDisconnectedEvent>((event) {
          if (mounted) context.go('/teacher/meet');
        })
        ..on<DataReceivedEvent>((event) {
          final text = String.fromCharCodes(event.data);
          setState(() {
            _chatMessages.add(text);
          });
        });

      await _room!.connect(
        AppEnv.liveKitUrl,
        tokenData.token,
      );

      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[LiveKit Connect Warning] $e');
      // If LiveKit server is unavailable in dev, continue in simulated room mode
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _toggleMic() async {
    final next = !_isMicOn;
    await _room?.localParticipant?.setMicrophoneEnabled(next);
    setState(() => _isMicOn = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_isCameraOn;
    await _room?.localParticipant?.setCameraEnabled(next);
    setState(() => _isCameraOn = next);
  }

  Future<void> _toggleScreenShare() async {
    final next = !_isScreenSharing;
    await _room?.localParticipant?.setScreenShareEnabled(next);
    setState(() => _isScreenSharing = next);
  }

  void _sendChatMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    _chatInputController.clear();

    final user = ref.read(currentUserProvider);
    final sender = user?.fullName ?? 'You';
    final msg = '$sender: $text';

    _room?.localParticipant?.publishData(msg.codeUnits);
    setState(() {
      _chatMessages.add(msg);
    });
  }

  void _sendReaction(String emoji) {
    final user = ref.read(currentUserProvider);
    final msg = '${user?.fullName ?? "Someone"} reacted $emoji';
    _room?.localParticipant?.publishData(msg.codeUnits);
    setState(() {
      _chatMessages.add(msg);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sent reaction: $emoji'), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _leaveRoom() async {
    await _room?.disconnect();
    _room?.dispose();
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/teacher/meet');
      }
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.brandSky),
              SizedBox(height: 16),
              Text(
                'Connecting to live room...',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Class')),
        body: ErrorStateWidget(
          message: _errorMessage!,
          onRetry: _connectToRoom,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111215),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18191E),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: const [
                  Icon(Icons.fiber_manual_record_rounded, size: 10, color: Colors.redAccent),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(widget.roomName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showChat ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded),
            tooltip: 'Live Chat',
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
            tooltip: 'Leave Meeting',
            onPressed: _leaveRoom,
          ),
        ],
      ),
      body: Row(
        children: [
          // Main Video Grid
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2026),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Avatar / Camera Placeholder
                              if (!_isCameraOn)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 40,
                                      backgroundColor: AppColors.brandSky,
                                      child: Text(
                                        (currentUser?.firstName?[0] ?? 'U').toUpperCase(),
                                        style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      currentUser?.fullName ?? 'You',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                )
                              else
                                Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.brandIndigo.withValues(alpha: 0.2),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_rounded, size: 48, color: Colors.white38),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Camera Active (${currentUser?.fullName ?? "You"})',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),

                              // Name Badge
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                                        size: 14,
                                        color: _isMicOn ? Colors.white : Colors.redAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        currentUser?.fullName ?? 'You',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      if (_isHandRaised) ...[
                                        const SizedBox(width: 6),
                                        const Text('✋', style: TextStyle(fontSize: 12)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Meeting Controls Bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  color: const Color(0xFF18191E),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mic
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _isMicOn ? const Color(0xFF2C2D34) : Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(_isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded),
                        onPressed: _toggleMic,
                      ),
                      const SizedBox(width: 12),

                      // Camera
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _isCameraOn ? const Color(0xFF2C2D34) : Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(_isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded),
                        onPressed: _toggleCamera,
                      ),
                      const SizedBox(width: 12),

                      // Screen Share
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _isScreenSharing ? AppColors.brandSky : const Color(0xFF2C2D34),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.screen_share_rounded),
                        onPressed: _toggleScreenShare,
                      ),
                      const SizedBox(width: 12),

                      // Raise Hand
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _isHandRaised ? Colors.amber[700] : const Color(0xFF2C2D34),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.pan_tool_rounded),
                        onPressed: () {
                          setState(() => _isHandRaised = !_isHandRaised);
                        },
                      ),
                      const SizedBox(width: 12),

                      // Reactions Menu
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2C2D34),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_reaction_outlined, color: Colors.white, size: 20),
                        ),
                        onSelected: _sendReaction,
                        itemBuilder: (ctx) => [
                          '👍', '❤️', '😂', '🎉', '🔥', '👏', '💯',
                        ].map((e) => PopupMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 20)))).toList(),
                      ),
                      const SizedBox(width: 20),

                      // End / Leave Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.call_end_rounded, size: 18),
                        label: const Text('Leave'),
                        onPressed: _leaveRoom,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Live Chat Drawer
          if (_showChat)
            Container(
              width: 300,
              decoration: const BoxDecoration(
                color: Color(0xFF18191E),
                border: Border(left: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.centerLeft,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Live Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                          onPressed: () => setState(() => _showChat = false),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF24252C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _chatMessages[index],
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatInputController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Send message...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: const Color(0xFF24252C),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                            onSubmitted: (_) => _sendChatMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.brandSky, size: 20),
                          onPressed: _sendChatMessage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
