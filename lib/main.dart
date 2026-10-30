import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/storage_service.dart';
import 'theme/whatsapp_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MessengerApp());
}

class MessengerApp extends StatelessWidget {
  const MessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
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
