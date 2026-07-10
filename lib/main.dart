import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:provider/provider.dart';
import 'config.dart';
import 'auth_state.dart';
import 'routes.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Required for deep-link email callback flow
    ),
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthState(),
      child: const IeltsApp(),
    ),
  );
}

class IeltsApp extends StatelessWidget {
  const IeltsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IELTSPrep',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Dynamically toggle theme mode based on OS settings
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      routerConfig: appRouter,
    );
  }
}
