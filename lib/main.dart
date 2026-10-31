import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/storage_service.dart';
import 'theme/whatsapp_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MessengerApp());
}

class MessengerApp extends StatelessWidget {
  const MessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider<AppUpdateService>.value(
          value: AppUpdateService.instance,
        ),
        Provider(create: (_) => ChatService()),
        Provider(create: (_) => StorageService()),
        Provider(create: (_) => PresenceService()),
        Provider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'RenChat',
        debugShowCheckedModeBanner: false,
        theme: WhatsAppTheme.lightTheme,
        darkTheme: WhatsAppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _initializedUid;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      _initializedUid = null;
      return const AuthScreen();
    }

    // Initialize presence and notification listeners once per user session
    final uid = auth.currentUid;
    if (uid != null && uid != _initializedUid) {
      _initializedUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PresenceService>().initialize(uid);
        context.read<NotificationService>().initialize(uid);
      });
    }

    return const HomeScreen();
  }
}
