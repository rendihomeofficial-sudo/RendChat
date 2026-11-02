import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_app/models/call_model.dart';
import 'package:messenger_app/theme/whatsapp_theme.dart';
import 'package:messenger_app/widgets/user_avatar.dart';

/// Komponen simulasi dialog panggilan masuk yang terisolasi untuk pengujian unit & widget
class MockIncomingCallDialog extends StatefulWidget {
  final CallModel call;
  final ValueChanged<bool> onAnswer; // true = terima, false = tolak

  const MockIncomingCallDialog({
    super.key,
    required this.call,
    required this.onAnswer,
  });

  @override
  State<MockIncomingCallDialog> createState() => _MockIncomingCallDialogState();
}

class _MockIncomingCallDialogState extends State<MockIncomingCallDialog> {
  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    return AlertDialog(
      backgroundColor: const Color(0xFF1F2C34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            call.isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
            key: const Key('incoming_call_type_icon'),
            color: WhatsAppTheme.primaryTeal,
          ),
          const SizedBox(width: 8),
          Text(
            call.isVideo ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk',
            key: const Key('incoming_call_title'),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          UserAvatar(
            name: call.callerName,
            photoUrl: call.callerAvatar,
            radius: 40,
          ),
          const SizedBox(height: 14),
          Text(
            call.callerName,
            key: const Key('caller_display_name'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Memanggil Anda di RenChat...',
            style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          key: const Key('btn_reject_call'),
          icon: const Icon(Icons.call_end_rounded),
          label: const Text('Tolak'),
          onPressed: () => widget.onAnswer(false),
        ),
        FilledButton.icon(
          key: const Key('btn_accept_call'),
          icon: Icon(call.isVideo ? Icons.videocam_rounded : Icons.call_rounded),
          label: const Text('Terima'),
          onPressed: () => widget.onAnswer(true),
        ),
      ],
    );
  }
}

/// Simulasi layar transisi kamera panggilan video setelah panggilan dijawab
class MockVideoCallView extends StatefulWidget {
  final bool initialIsVideo;
  final bool isFrontCamera;

  const MockVideoCallView({
    super.key,
    required this.initialIsVideo,
    this.isFrontCamera = true,
  });

  @override
  State<MockVideoCallView> createState() => _MockVideoCallViewState();
}

class _MockVideoCallViewState extends State<MockVideoCallView> {
  late bool _isVideo;
  late bool _isFrontCamera;
  bool _isCameraActive = false;

  @override
  void initState() {
    super.initState();
    _isVideo = widget.initialIsVideo;
    _isFrontCamera = widget.isFrontCamera;
    if (_isVideo) {
      _isCameraActive = true;
    }
  }

  void toggleVideoMode() {
    setState(() {
      _isVideo = !_isVideo;
      _isCameraActive = _isVideo;
    });
  }

  void switchCameraLens() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Text(
              _isVideo ? 'Streaming Video HD Aktif' : 'Panggilan Suara Aktif',
              key: const Key('stream_status_text'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (_isVideo && _isCameraActive)
            Positioned(
              right: 16,
              bottom: 80,
              child: Container(
                key: const Key('pip_camera_container'),
                width: 110,
                height: 160,
                color: const Color(0xFF1B2830),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isFrontCamera ? Icons.camera_front_rounded : Icons.camera_rear_rounded,
                      key: Key(_isFrontCamera ? 'icon_camera_front' : 'icon_camera_rear'),
                      color: WhatsAppTheme.primaryTeal,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isFrontCamera ? 'Kamera Depan' : 'Kamera Belakang',
                      key: const Key('camera_lens_label'),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  group('Simulasi Alur Penerimaan Panggilan Video & Transisi Kamera Otomatis', () {
    testWidgets('1. Dialog panggilan video masuk mendeteksi mode video dan menampilkan tombol terima kamera', (tester) async {
      bool? userAction;

      final incomingVideoCall = CallModel(
        id: 'call_test_video_1',
        callerId: 'user_rendi',
        callerName: 'Rendi Pratama',
        callerAvatar: null,
        receiverId: 'user_me',
        receiverName: 'Saya',
        isVideo: true,
        status: 'calling',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MockIncomingCallDialog(
              call: incomingVideoCall,
              onAnswer: (action) => userAction = action,
            ),
          ),
        ),
      );

      // Verifikasi dialog panggilan video
      expect(find.text('Panggilan Video Masuk'), findsOneWidget);
      expect(find.text('Rendi Pratama'), findsOneWidget);
      expect(find.byKey(const Key('incoming_call_type_icon')), findsOneWidget);
      expect(find.byKey(const Key('btn_accept_call')), findsOneWidget);

      // Tekan tombol Terima
      await tester.tap(find.byKey(const Key('btn_accept_call')));
      await tester.pumpAndSettle();

      expect(userAction, isTrue);
    });

    testWidgets('2. Kamera otomatis menyala seketika di jendela PIP saat panggilan video diterima', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MockVideoCallView(
            initialIsVideo: true,
            isFrontCamera: true,
          ),
        ),
      );

      // Verifikasi status video dan jendela PIP aktif
      expect(find.byKey(const Key('stream_status_text')), findsOneWidget);
      expect(find.text('Streaming Video HD Aktif'), findsOneWidget);
      expect(find.byKey(const Key('pip_camera_container')), findsOneWidget);
      expect(find.byKey(const Key('icon_camera_front')), findsOneWidget);
      expect(find.text('Kamera Depan'), findsOneWidget);
    });

    testWidgets('3. Perpindahan swap dinamis dari panggilan video ke suara mematikan kamera PIP', (tester) async {
      final stateKey = GlobalKey<_MockVideoCallViewState>();

      await tester.pumpWidget(
        MaterialApp(
          home: MockVideoCallView(
            key: stateKey,
            initialIsVideo: true,
            isFrontCamera: true,
          ),
        ),
      );

      expect(find.byKey(const Key('pip_camera_container')), findsOneWidget);

      // Lakukan swap ke panggilan suara
      stateKey.currentState?.toggleVideoMode();
      await tester.pumpAndSettle();

      // Kamera PIP harus hilang
      expect(find.byKey(const Key('pip_camera_container')), findsNothing);
      expect(find.text('Panggilan Suara Aktif'), findsOneWidget);

      // Swap kembali ke panggilan video -> kamera PIP menyala seketika
      stateKey.currentState?.toggleVideoMode();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pip_camera_container')), findsOneWidget);
      expect(find.text('Streaming Video HD Aktif'), findsOneWidget);
    });

    testWidgets('4. Perpindahan flip kamera dari kamera depan ke kamera belakang berlangsung responsif', (tester) async {
      final stateKey = GlobalKey<_MockVideoCallViewState>();

      await tester.pumpWidget(
        MaterialApp(
          home: MockVideoCallView(
            key: stateKey,
            initialIsVideo: true,
            isFrontCamera: true,
          ),
        ),
      );

      expect(find.byKey(const Key('icon_camera_front')), findsOneWidget);
      expect(find.text('Kamera Depan'), findsOneWidget);

      // Balik kamera ke belakang
      stateKey.currentState?.switchCameraLens();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('icon_camera_rear')), findsOneWidget);
      expect(find.text('Kamera Belakang'), findsOneWidget);
    });
  });
}
