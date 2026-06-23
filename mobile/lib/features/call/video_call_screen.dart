import 'dart:async';

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

  // True once we've already told the backend the call is over (via any exit
  // path). Guards dispose() from posting a second /end and, crucially, makes
  // the Android system Back button / swipe-back end the call too — previously
  // backing out only tore down Agora locally, leaving the consultation
  // RINGING/ACTIVE and the lawyer-busy lock held for up to 65 minutes.
  bool _ended = false;

  // Client-side safety net only. The server owns the authoritative ring
  // timeout (45s) and fires call:ended with reason: 'no_answer'. We wait a
  // bit longer here so the server's MISSED-call recording wins the race if
  // the network delays the event.
  static const Duration _noAnswerTimeout = Duration(seconds: 55);
  Timer? _noAnswerTimer;

  // When the peer drops from the channel because their NETWORK died (Agora
  // reason: dropped) — as opposed to deliberately hanging up (reason: quit) —
  // give them a grace window to auto-rejoin instead of tearing the call down
  // on the first blip.
  static const Duration _peerReconnectGrace = Duration(seconds: 30);
  Timer? _peerReconnectTimer;
  bool _peerReconnecting = false;

  // Named handlers — we must remove ONLY these, not all socket listeners
  late final void Function(dynamic) _rejectedHandler;
  late final void Function(dynamic) _endedHandler;

  bool get _isVoice => widget.args.callType == 'VOICE';

  @override
  void initState() {
    super.initState();
    _rejectedHandler = (_) => _onRemoteEnd('Call declined.');
    _endedHandler    = (data) {
      // Server fires call:ended with reason: 'no_answer' when the 45s ring
      // timer expires without an accept. Show appropriate copy.
      String? msg;
      if (data is Map && data['reason'] == 'no_answer') {
        msg = 'No answer.';
      }
      _onRemoteEnd(msg);
    };
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
    if (socket == null) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }
    socket.on('call:rejected', _rejectedHandler);
    socket.on('call:ended',    _endedHandler);

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));

    // Always enable the audio module. For video calls, enableVideo() would
    // implicitly enable audio too, but being explicit is safer; for voice
    // calls this is REQUIRED — otherwise the mic isn't captured and the
    // remote peer hears silence.
    await engine.enableAudio();

    if (!_isVoice) {
      await engine.enableVideo();
      await engine.startPreview();
    } else {
      // Voice-only: route audio through the loud speaker by default so the
      // call behaves like WhatsApp / phone calls, not earpiece-quiet.
      await engine.setEnableSpeakerphone(true);
    }

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (_, _) {
          // Re-assert speakerphone for voice calls. Setting it before
          // joinChannel doesn't reliably stick on some Agora/Android builds —
          // the audio route is only locked in once we're actually in the
          // channel, so without this voice calls can come out the quiet
          // earpiece instead of the loudspeaker.
          if (_isVoice) {
            engine.setEnableSpeakerphone(true);
          }
          if (mounted) setState(() => _joined = true);
        },
        onUserJoined: (_, remoteUid, _) {
          // Peer picked up (or came back after a network blip) — cancel the
          // no-answer fallback and any pending reconnect-grace teardown.
          _noAnswerTimer?.cancel();
          _noAnswerTimer = null;
          _peerReconnectTimer?.cancel();
          _peerReconnectTimer = null;
          if (mounted) {
            setState(() {
              _peerReconnecting = false;
              _remoteUids.add(remoteUid);
            });
          }
        },
        onUserOffline: (_, remoteUid, reason) {
          if (!mounted) return;
          setState(() => _remoteUids.remove(remoteUid));
          if (reason == UserOfflineReasonType.userOfflineDropped) {
            // Peer's NETWORK dropped — they didn't hang up. Agora will bring
            // them back automatically when connectivity returns; give them a
            // grace window before declaring the call dead. Previously any
            // blip on the peer's side instantly ended the whole call.
            setState(() => _peerReconnecting = true);
            _peerReconnectTimer?.cancel();
            _peerReconnectTimer = Timer(_peerReconnectGrace, () {
              if (mounted && _remoteUids.isEmpty) {
                _onRemoteEnd('Call ended — connection lost.');
              }
            });
            return;
          }
          // Peer deliberately left the channel (hung up, force-closed app).
          // Treat as call ended — without this, the caller's screen sat on
          // "Waiting for the other party…" forever after the receiver hung
          // up. POST /end is idempotent so it's safe to fire here even if
          // the peer's own /end already flipped DB status.
          _onRemoteEnd('Call ended');
        },
        // Fires ~30 s before the current Agora token expires.
        // We mint a fresh one from the backend and hand it back to the engine
        // so calls longer than 1 hour don't get force-disconnected.
        onTokenPrivilegeWillExpire: (_, _) => _refreshAgoraToken(),
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

    // Start the no-answer timer. Cancelled when the remote peer joins, when
    // we hang up, when call:rejected / call:ended arrives, or on dispose.
    _noAnswerTimer = Timer(_noAnswerTimeout, _onNoAnswer);

    if (mounted) setState(() {});
  }

  Future<void> _refreshAgoraToken() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      final resp = await ref.read(apiClientProvider)
          .post('/call/${widget.args.consultationId}/token');
      final data = resp['data'] as Map<String, dynamic>?;
      final fresh = data?['agoraToken'] as String?;
      if (fresh == null || fresh.isEmpty) return;
      await engine.renewToken(fresh);
    } catch (_) {
      // Renewal failed — Agora will surface its own onError when the
      // current token actually expires; we don't need to crash the call here.
    }
  }

  Future<void> _onNoAnswer() async {
    if (!mounted || _remoteUids.isNotEmpty) return;
    // Same teardown path as hang-up, but surfaces a "No answer" message.
    _ended = true;
    final socket = ref.read(socketServiceProvider).socket;
    socket?.off('call:rejected', _rejectedHandler);
    socket?.off('call:ended',    _endedHandler);
    try {
      await ref.read(apiClientProvider).post('/call/${widget.args.consultationId}/end');
    } catch (_) {}
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(const SnackBar(content: Text('No answer.')));
  }

  /// Re-entrancy guard — _onRemoteEnd can be triggered from multiple
  /// sources concurrently (call:ended socket event, call:rejected,
  /// Agora's onUserOffline). Without this guard the second invocation
  /// would try to pop a screen that's already gone.
  bool _ending = false;

  void _onRemoteEnd(String? message) {
    if (!mounted || _ending) return;
    _ending = true;
    _ended  = true;
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    _peerReconnectTimer?.cancel();
    _peerReconnectTimer = null;
    final messenger = message != null ? ScaffoldMessenger.maybeOf(context) : null;
    // Fire-and-forget /end so the backend marks the consultation ENDED and
    // the lawyer-busy lock is released. If the peer already POSTed /end
    // (because they were the one who hung up), this is idempotent — the
    // backend's end() handler safely tolerates double-ends.
    ref.read(apiClientProvider)
        .post('/call/${widget.args.consultationId}/end')
        .catchError((_) => null);
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
    final socket = ref.read(socketServiceProvider).socket;
    socket?.off('call:rejected', _rejectedHandler);
    socket?.off('call:ended',    _endedHandler);
    Navigator.of(context).pop();
    if (message != null && messenger != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _hangUp() async {
    _ended = true;
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    _peerReconnectTimer?.cancel();
    _peerReconnectTimer = null;
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
    _noAnswerTimer?.cancel();
    _peerReconnectTimer?.cancel();
    final socket = ref.read(socketServiceProvider).socket;
    socket?.off('call:rejected', _rejectedHandler);
    socket?.off('call:ended',    _endedHandler);
    // If the screen is being torn down by the system Back button / swipe-back
    // (no hang-up button, no remote end), none of the explicit teardown paths
    // ran — so the backend still thinks the call is live. Fire-and-forget /end
    // so the consultation is marked ENDED and the lawyer-busy lock is freed.
    // /end is idempotent, so this is safe even if it races a normal teardown.
    if (!_ended) {
      ref.read(apiClientProvider)
          .post('/call/${widget.args.consultationId}/end')
          .catchError((_) => null);
    }
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
                ? (_peerReconnecting ? 'Reconnecting…' : 'Waiting for answer…')
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
          Text(
            _peerReconnecting ? 'Reconnecting…' : 'Waiting for the other party…',
            style: const TextStyle(color: Colors.white70),
          ),
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
