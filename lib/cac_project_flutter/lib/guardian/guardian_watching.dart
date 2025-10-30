import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

class GuardianWatchingPage extends StatefulWidget {
  const GuardianWatchingPage({
    super.key,
    required this.livekitUrl,     // same wss://... as navigator
    required this.guardianToken,  // token with metadata "role=guardian" (recommended)
  });

  final String livekitUrl;
  final String guardianToken;

  @override
  State<GuardianWatchingPage> createState() => _GuardianWatchingPageState();
}

class _GuardianWatchingPageState extends State<GuardianWatchingPage> {
  late final lk.Room _room;

  @override
  void initState() {
    super.initState();
    _room = lk.Room(connectOptions: const lk.ConnectOptions(autoSubscribe: true));
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _room.connect(widget.livekitUrl, widget.guardianToken);
      setState(() {});
    } catch (e) {
      debugPrint('Guardian connect failed: $e');
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }
lk.VideoTrack? _firstRemoteVideo() {
  if (_room.remoteParticipants.isEmpty) {
    debugPrint('No remote participants found');
    return null;
  }
  for (final p in _room.remoteParticipants.values) {
    debugPrint('Remote participant: ${p.identity}'); // Log participant identity
    for (final pub in p.videoTrackPublications) {
      final t = pub.track;
      if (t is lk.VideoTrack) {
        debugPrint('Found video track for participant ${p.identity}');
        return t;
      }
    }
  }
  debugPrint('No video tracks found for remote participants');
  return null;
}

  @override
  Widget build(BuildContext context) {
    final vt = _firstRemoteVideo();
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian — Viewing')),
      body: Center(
        child: vt == null
            ? const Text('Waiting for live video…')
            : lk.VideoTrackRenderer(
                vt,
                // LiveKit 2.x uses VideoViewFit enum
                fit: lk.VideoViewFit.cover,
              ),
      ),
    );
  }
}
