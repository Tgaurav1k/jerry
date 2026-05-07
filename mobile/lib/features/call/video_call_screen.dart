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
  });

  final String consultationId;
  final String channelId;
  final String token;
  final int uid;
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
  bool _joined = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final appId = Env.agoraAppId.trim();
    if (appId.isEmpty) {
      setState(() => _error = 'Set AGORA_APP_ID in mobile/.env (same App ID as backend).');
      return;
    }

    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      setState(() => _error = 'Camera and microphone permission required.');
      return;
    }

    // Listen for rejection or remote hang-up via Socket.IO
    final socket = await ref.read(socketServiceProvider).connect();
    socket.on('call:rejected', (_) => _onRemoteEnd('Call declined by lawyer.'));
    socket.on('call:ended', (_) => _onRemoteEnd(null));

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));
    await engine.enableVideo();
    await engine.startPreview();

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection c, int elapsed) {
          if (mounted) setState(() => _joined = true);
        },
        onUserJoined: (RtcConnection c, int remoteUid, int elapsed) {
          if (mounted) setState(() => _remoteUids.add(remoteUid));
        },
        onUserOffline: (RtcConnection c, int remoteUid, UserOfflineReasonType reason) {
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
    socket?.off('call:rejected');
    socket?.off('call:ended');
    Navigator.of(context).pop();
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _hangUp() async {
    try {
      await ref.read(apiClientProvider).post('/call/${widget.args.consultationId}/end');
    } catch (_) {}
    final socket = ref.read(socketServiceProvider).socket;
    socket?.off('call:rejected');
    socket?.off('call:ended');
    await _engine?.leaveChannel();
    await _engine?.release();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    final socket = ref.read(socketServiceProvider).socket;
    socket?.off('call:rejected');
    socket?.off('call:ended');
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = _error;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: e != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(e, style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                    ],
                  ),
                ),
              )
            : _engine == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _remoteView(),
                      Positioned(
                        right: 16,
                        bottom: 100,
                        width: 120,
                        height: 160,
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
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                              onPressed: _hangUp,
                              child: const Text('End call'),
                            ),
                          ],
                        ),
                      ),
                      if (!_joined)
                        const Positioned(
                          top: 24,
                          left: 0,
                          right: 0,
                          child: Text(
                            'Connecting…',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _remoteView() {
    final engine = _engine!;
    if (_remoteUids.isEmpty) {
      return Container(
        color: AppColors.slate800,
        alignment: Alignment.center,
        child: const Text(
          'Waiting for the other party…',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final r = _remoteUids.first;
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: r),
        connection: RtcConnection(channelId: widget.args.channelId),
      ),
    );
  }
}
