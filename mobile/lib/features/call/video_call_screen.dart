import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jerry_app/core/config/env.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallArgs {
  VideoCallArgs({
    required this.consultationId,
    required this.channelId,
    required this.token,
    required this.uid,
    this.callType = 'VIDEO',
    this.peerName,
  });

  final String  consultationId;
  final String  channelId;
  final String  token;
  final int     uid;
  final String  callType;   // 'VIDEO' | 'VOICE'
  final String? peerName;
}

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key, required this.args});

  static const routePath = '/video-call';
  static const routeName = 'video-call';

  final VideoCallArgs args;

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  RtcEngine? _engine;
  final Set<int> _remoteUids = {};
  bool _joined  = false;
  bool _muted   = false;
  String? _error;

  // Named handlers — we must remove ONLY these, not all socket listeners
  late final void Function(dynamic) _rejectedHandler;
  late final void Function(dynamic) _endedHandler;

  bool get _isVoice => widget.args.callType == 'VOICE';

  @override
  void initState() {
    super.initState();
    _rejectedHandler = (_) => _onRemoteEnd('Call declined.');
    _endedHandler    = (_) => _onRemoteEnd(null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final appId = Env.agoraAppId.trim();
    if (appId.isEmpty) {
      setState(() => _error = 'Set AGORA_APP_ID in mobile/.env');
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      setState(() => _error = 'Microphone permission required.');
      return;
    }
    if (!_isVoice) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        setState(() => _error = 'Camera permission required.');
        return;
      }
    }

    // Register only our own handlers so dispose() can remove just them
    final socket = await ref.read(socketServiceProvider).connect();
    socket.on('call:rejected', _rejectedHandler);
    socket.on('call:ended',    _endedHandler);

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));

    if (!_isVoice) {
      await engine.enableVideo();
      await engine.startPreview();
    }

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (_, _) {
          if (mounted) setState(() => _joined = true);
        },
        onUserJoined: (_, remoteUid, _) {
          if (mounted) setState(() => _remoteUids.add(remoteUid));
        },
        onUserOffline: (_, remoteUid, _) {
          if (mounted) setState(() => _remoteUids.remove(remoteUid));
        },
        onError: (code, msg) {
          if (mounted) setState(() => _error = 'Agora error $code: $msg');
        },
      ),
    );

    _engine = engine;

    await engine.joinChannel(
      token: widget.args.token,
      channelId: widget.args.channelId,
      uid: widget.args.uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    if (mounted) setState(() {});
  }

  void _onRemoteEnd(String? message) {
    if (!mounted) return;
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
    final socket = ref.read(socketServiceProvider).socket;
    socket?.off('call:rejected', _rejectedHandler);
    socket?.off('call:ended',    _endedHandler);
    Navigator.of(context).pop();
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _hangUp() async {
    // Remove our listeners before posting end, so the returning call:ended
    // event is handled only by chat_provider (for the call bubble)
    final socket = ref.read(socketServiceProvider).socket;
    socket?.off('call:rejected', _rejectedHandler);
    socket?.off('call:ended',    _endedHandler);
    try {
      await ref.read(apiClientProvider).post('/call/${widget.args.consultationId}/end');
    } catch (_) {}
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    _muted = !_muted;
    _engine?.muteLocalAudioStream(_muted);
    setState(() {});
  }

  @override
  void dispose() {
    final socket = ref.read(socketServiceProvider).socket;
    socket?.off('call:rejected', _rejectedHandler);
    socket?.off('call:ended',    _endedHandler);
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final e = _error;
    if (e != null) return _errorView(e);

    return _isVoice ? _buildVoiceUI() : _buildVideoUI();
  }

  Widget _errorView(String msg) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(msg, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              ]),
            ),
          ),
        ),
      );

  // ─── Voice UI ────────────────────────────────────────────────────────────

  Widget _buildVoiceUI() {
    final name   = widget.args.peerName ?? 'Caller';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final status = _engine == null
        ? 'Connecting…'
        : !_joined
            ? 'Ringing…'
            : _remoteUids.isEmpty
                ? 'Waiting for answer…'
                : 'Connected';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          CircleAvatar(
            radius: 56,
            backgroundColor: AppColors.blue500,
            child: Text(initials, style: const TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(status, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const Spacer(),
          _callControls(isVideo: false),
          const SizedBox(height: 48),
        ]),
      ),
    );
  }

  // ─── Video UI ─────────────────────────────────────────────────────────────

  Widget _buildVideoUI() {
    if (_engine == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _remoteView(),
            // Local preview (small, bottom-right)
            Positioned(
              right: 16, bottom: 100, width: 120, height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
            // Status
            if (!_joined)
              const Positioned(
                top: 24, left: 0, right: 0,
                child: Text('Connecting…', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70)),
              ),
            // Controls
            Positioned(
              left: 0, right: 0, bottom: 24,
              child: _callControls(isVideo: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _remoteView() {
    final engine = _engine!;
    if (_remoteUids.isEmpty) {
      final name     = widget.args.peerName ?? '';
      final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
      return Container(
        color: AppColors.slate800,
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.blue500,
            child: Text(initials, style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          const Text('Waiting for the other party…', style: TextStyle(color: Colors.white70)),
        ]),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: _remoteUids.first),
        connection: RtcConnection(channelId: widget.args.channelId),
      ),
    );
  }

  // ─── Shared controls row ─────────────────────────────────────────────────

  Widget _callControls({required bool isVideo}) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mute button
          _CircleButton(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: _muted ? Colors.white : Colors.white30,
            onTap: _toggleMute,
          ),
          const SizedBox(width: 32),
          // Hang-up
          _CircleButton(
            icon: Icons.call_end_rounded,
            color: AppColors.error,
            size: 64,
            onTap: _hangUp,
          ),
        ],
      );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 52,
  });

  final IconData   icon;
  final Color      color;
  final VoidCallback onTap;
  final double     size;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: size * 0.46),
        ),
      );
}
