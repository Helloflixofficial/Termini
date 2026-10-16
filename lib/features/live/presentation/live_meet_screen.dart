import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/config/env.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/livekit_repository.dart';

const _canvas = Color(0xFF202127);
const _panel = Color(0xFF2B2D35);
const _green = Color(0xFF35D07F);

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
  final List<_RoomMessage> _messages = [];
  final Map<String, String> _reactions = {};
  final Set<String> _speakers = {};
  final Set<String> _raisedHands = {};
  final _chatInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    await _disposeRoom();

    try {
      final tokenData = await ref
          .read(liveKitRepositoryProvider)
          .getToken(widget.roomName);
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room;
      _listener = room.createListener()
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted) context.go('/shortmeet');
        })
        ..on<ActiveSpeakersChangedEvent>((event) {
          if (!mounted) return;
          setState(() {
            _speakers
              ..clear()
              ..addAll(
                event.speakers.map((participant) => participant.identity),
              );
          });
        })
        ..on<DataReceivedEvent>((event) => _handleRoomData(event.data))
        ..on<ParticipantConnectedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          if (!mounted) return;
          setState(() {
            _speakers.remove(event.participant.identity);
            _raisedHands.remove(event.participant.identity);
            _reactions.remove(event.participant.identity);
          });
        })
        ..on<TrackSubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackMutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnmutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackPublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnpublishedEvent>((_) {
          if (mounted) setState(() {});
        });

      await room.connect(AppEnv.liveKitUrl, tokenData.token);
      try {
        await room.localParticipant?.setCameraEnabled(true);
        _isCameraOn = true;
      } catch (_) {
        _isCameraOn = false;
      }
      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
        _isMicOn = true;
      } catch (_) {
        _isMicOn = false;
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      debugPrint('[LiveKit Connect Error] $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not connect to this live class. Check your connection or ask your teacher to confirm the session is active.';
      });
    }
  }

  void _handleRoomData(List<int> bytes) {
    try {
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final identity = data['identity'] as String?;
      final name = data['name'] as String? ?? 'Participant';
      if (identity != null && identity == _room?.localParticipant?.identity) {
        return;
      }
      if (!mounted) return;
      setState(() {
        switch (data['type']) {
          case 'chat':
            final text = data['text'] as String?;
            if (text != null && text.isNotEmpty) {
              _messages.add(_RoomMessage(name, text));
            }
          case 'reaction':
            final emoji = data['emoji'] as String?;
            if (identity != null && emoji != null) _reactions[identity] = emoji;
          case 'hand':
            if (identity == null) return;
            if (data['raised'] == true) {
              _raisedHands.add(identity);
            } else {
              _raisedHands.remove(identity);
            }
        }
      });
    } catch (_) {
      // Ignore data sent by older clients or unrelated room-data publishers.
    }
  }

  Future<void> _publish(Map<String, Object?> payload) async {
    final user = ref.read(currentUserProvider);
    final participant = _room?.localParticipant;
    if (participant == null) return;
    payload['identity'] = participant.identity;
    payload['name'] = user?.fullName ?? participant.name;
    try {
      await participant.publishData(utf8.encode(jsonEncode(payload)));
    } catch (error) {
      _showMessage('Could not send that to the room.');
      debugPrint('[LiveKit Data Error] $error');
    }
  }

  Future<void> _toggleMic() async {
    final next = !_isMicOn;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(next);
      if (mounted) setState(() => _isMicOn = next);
    } catch (_) {
      _showMessage('Microphone could not be changed. Check app permissions.');
    }
  }

  Future<void> _toggleCamera() async {
    final next = !_isCameraOn;
    try {
      await _room?.localParticipant?.setCameraEnabled(next);
      if (mounted) setState(() => _isCameraOn = next);
    } catch (_) {
      _showMessage('Camera could not be changed. Check app permissions.');
    }
  }

  Future<void> _toggleScreenShare() async {
    final room = _room;
    if (room == null) return;
    final next = !_isScreenSharing;
    try {
      if (next && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final config = FlutterBackgroundAndroidConfig(
          notificationTitle: 'Termini class is sharing your screen',
          notificationText: 'Screen sharing is active',
          notificationImportance: AndroidNotificationImportance.normal,
        );
        final initialized = await FlutterBackground.initialize(
          androidConfig: config,
        );
        if (!initialized || !await Helper.requestCapturePermission()) {
          _showMessage('Screen sharing permission was not granted.');
          return;
        }
        if (!await FlutterBackground.enableBackgroundExecution()) {
          _showMessage('Android could not start the screen sharing service.');
          return;
        }
      }
      await room.localParticipant?.setScreenShareEnabled(next);
      if (mounted) setState(() => _isScreenSharing = next);
      if (!next &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (error) {
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      _showMessage('Screen sharing failed on this device.');
      debugPrint('[Screen Share Error] $error');
    }
  }

  Future<void> _toggleHand() async {
    final raised = !_isHandRaised;
    setState(() => _isHandRaised = raised);
    if (raised) {
      _raisedHands.add(_room?.localParticipant?.identity ?? '');
    } else {
      _raisedHands.remove(_room?.localParticipant?.identity);
    }
    await _publish({'type': 'hand', 'raised': raised});
  }

  Future<void> _sendChatMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    _chatInputController.clear();
    final user = ref.read(currentUserProvider);
    final name = user?.fullName ?? 'You';
    setState(() => _messages.add(_RoomMessage(name, text)));
    await _publish({'type': 'chat', 'text': text});
  }

  Future<void> _sendReaction(String emoji) async {
    final identity = _room?.localParticipant?.identity;
    if (identity != null) setState(() => _reactions[identity] = emoji);
    await _publish({'type': 'reaction', 'emoji': emoji});
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _leaveRoom() async {
    await _disposeRoom();
    if (mounted) context.go('/shortmeet');
  }

  Future<void> _disposeRoom() async {
    _listener?.dispose();
    _listener = null;
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
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
    final room = _room;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _canvas,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _green),
              SizedBox(height: 16),
              Text(
                'Joining your live class…',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    if (_errorMessage != null || room == null) {
      return Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          backgroundColor: _canvas,
          foregroundColor: Colors.white,
          title: const Text('Live class'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Colors.white54,
                ),
                const SizedBox(height: 18),
                Text(
                  _errorMessage ?? 'The live room is unavailable.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _connectToRoom,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
    final compact = MediaQuery.sizeOf(context).width < 760;
    final chat = _ChatPanel(
      messages: _messages,
      input: _chatInputController,
      onSend: _sendChatMessage,
      onClose: () {
        if (compact) {
          Navigator.of(context).pop();
        } else {
          setState(() => _showChat = false);
        }
      },
    );

    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.school_rounded, color: _green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.roomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${participants.length} in class',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Colors.redAccent, size: 8),
                  SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open class chat',
            onPressed: () => compact
                ? _openMobileChat(context, chat)
                : setState(() => _showChat = !_showChat),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: participants.isEmpty
                      ? const Center(
                          child: Text(
                            'Waiting for classmates…',
                            style: TextStyle(color: Colors.white60),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final count = participants.length;
                            final columns = constraints.maxWidth < 500
                                ? 1
                                : constraints.maxWidth < 900
                                ? 2
                                : (count <= 4 ? 2 : 3);
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: columns == 1 ? 1.5 : 1.65,
                                  ),
                              itemCount: participants.length,
                              itemBuilder: (context, index) {
                                final participant = participants[index];
                                final local =
                                    participant.identity ==
                                    room.localParticipant?.identity;
                                final isSpeaking = _speakers.contains(
                                  participant.identity,
                                );
                                final hand =
                                    _raisedHands.contains(
                                      participant.identity,
                                    ) ||
                                    (local && _isHandRaised);
                                return _ParticipantTile(
                                  key: ValueKey(participant.identity),
                                  participant: participant,
                                  isLocal: local,
                                  isSpeaking: isSpeaking,
                                  handRaised: hand,
                                  reaction: _reactions[participant.identity],
                                  micOn: local
                                      ? _isMicOn
                                      : participant.audioTrackPublications.any(
                                          (p) => !p.muted,
                                        ),
                                  cameraOn: local
                                      ? _isCameraOn
                                      : participant.videoTrackPublications.any(
                                          (p) =>
                                              p.source == TrackSource.camera &&
                                              !p.muted &&
                                              p.track != null,
                                        ),
                                );
                              },
                            );
                          },
                        ),
                ),
                _ControlBar(
                  micOn: _isMicOn,
                  cameraOn: _isCameraOn,
                  sharing: _isScreenSharing,
                  handRaised: _isHandRaised,
                  chatOpen: _showChat,
                  onMic: _toggleMic,
                  onCamera: _toggleCamera,
                  onShare: _toggleScreenShare,
                  onHand: _toggleHand,
                  onChat: () => compact
                      ? _openMobileChat(context, chat)
                      : setState(() => _showChat = !_showChat),
                  onReaction: _sendReaction,
                  onLeave: _leaveRoom,
                ),
              ],
            ),
          ),
          if (_showChat && !compact) SizedBox(width: 320, child: chat),
        ],
      ),
    );
  }

  void _openMobileChat(BuildContext context, Widget chat) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: chat,
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isLocal;
  final bool isSpeaking;
  final bool handRaised;
  final String? reaction;
  final bool micOn;
  final bool cameraOn;

  const _ParticipantTile({
    super.key,
    required this.participant,
    required this.isLocal,
    required this.isSpeaking,
    required this.handRaised,
    required this.reaction,
    required this.micOn,
    required this.cameraOn,
  });

  @override
  Widget build(BuildContext context) {
    final videoPublication = participant.videoTrackPublications
        .cast<TrackPublication?>()
        .firstWhere(
          (publication) =>
              publication != null &&
              publication.track is VideoTrack &&
              !publication.muted &&
              (publication.source == TrackSource.camera ||
                  publication.isScreenShare),
          orElse: () => null,
        );
    final videoTrack = videoPublication?.track;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF30323A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSpeaking ? _green : Colors.white.withValues(alpha: .09),
          width: isSpeaking ? 3 : 1,
        ),
        boxShadow: isSpeaking
            ? [BoxShadow(color: _green.withValues(alpha: .22), blurRadius: 18)]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack is VideoTrack)
            VideoTrackRenderer(videoTrack, fit: VideoViewFit.cover)
          else
            Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFF5865F2),
                child: Text(
                  participant.name.isNotEmpty
                      ? participant.name.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          if (reaction != null)
            Positioned(
              top: 10,
              right: 12,
              child: Text(reaction!, style: const TextStyle(fontSize: 32)),
            ),
          if (!cameraOn && videoTrack == null)
            const Center(
              child: Icon(
                Icons.videocam_off_rounded,
                color: Colors.white24,
                size: 20,
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        if (handRaised)
                          const Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: Text('✋'),
                          ),
                        Expanded(
                          child: Text(
                            '${participant.name}${isLocal ? ' (You)' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                          size: 15,
                          color: micOn ? Colors.white70 : Colors.redAccent,
                        ),
                      ],
                    ),
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

class _ControlBar extends StatelessWidget {
  final bool micOn, cameraOn, sharing, handRaised, chatOpen;
  final VoidCallback onMic, onCamera, onShare, onHand, onChat, onLeave;
  final ValueChanged<String> onReaction;

  const _ControlBar({
    required this.micOn,
    required this.cameraOn,
    required this.sharing,
    required this.handRaised,
    required this.chatOpen,
    required this.onMic,
    required this.onCamera,
    required this.onShare,
    required this.onHand,
    required this.onChat,
    required this.onReaction,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 7,
          runSpacing: 8,
          children: [
            _RoundControl(
              icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              label: micOn ? 'Mute' : 'Unmute',
              active: micOn,
              onPressed: onMic,
            ),
            _RoundControl(
              icon: cameraOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: 'Camera',
              active: cameraOn,
              onPressed: onCamera,
            ),
            _RoundControl(
              icon: Icons.screen_share_rounded,
              label: 'Share',
              active: sharing,
              onPressed: onShare,
            ),
            _RoundControl(
              icon: Icons.pan_tool_rounded,
              label: 'Hand',
              active: handRaised,
              onPressed: onHand,
            ),
            PopupMenuButton<String>(
              tooltip: 'Send reaction',
              onSelected: onReaction,
              color: _panel,
              itemBuilder: (_) => ['👍', '❤️', '😂', '🎉', '🔥', '👏', '💯']
                  .map(
                    (emoji) => PopupMenuItem(
                      value: emoji,
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  )
                  .toList(),
              child: const _ControlFace(
                icon: Icons.add_reaction_outlined,
                label: 'React',
              ),
            ),
            _RoundControl(
              icon: chatOpen
                  ? Icons.chat_rounded
                  : Icons.chat_bubble_outline_rounded,
              label: 'Chat',
              active: chatOpen,
              onPressed: onChat,
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFED4245),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
              ),
              onPressed: onLeave,
              icon: const Icon(Icons.call_end_rounded, size: 17),
              label: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(13),
    child: _ControlFace(icon: icon, label: label, active: active),
  );
}

class _ControlFace extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _ControlFace({
    required this.icon,
    required this.label,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 62,
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      color: active ? _green.withValues(alpha: .22) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? _green : Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _ChatPanel extends StatelessWidget {
  final List<_RoomMessage> messages;
  final TextEditingController input;
  final VoidCallback onSend, onClose;
  const _ChatPanel({
    required this.messages,
    required this.input,
    required this.onSend,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: _panel,
    child: Column(
      children: [
        ListTile(
          title: const Text(
            'Class chat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          trailing: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    'Say hello to your class',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.sender,
                            style: const TextStyle(
                              color: _green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Message classmates',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: _canvas,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded, color: _green),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoomMessage {
  final String sender;
  final String text;
  const _RoomMessage(this.sender, this.text);
}
