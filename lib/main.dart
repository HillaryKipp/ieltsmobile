import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:provider/provider.dart';
import 'config.dart';
import 'auth_state.dart';
import 'routes.dart';
import 'theme.dart';

import 'widgets/error_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error presentation handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Unhandled Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Dispatcher Error: $error');
    return true;
  };

  // Graceful fallback for UI rendering exceptions
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: SafeArea(
        child: ErrorView(
          title: 'Display Error',
          message: 'A visual component encountered an issue. Please try refreshing.',
          icon: Icons.warning_amber_rounded,
        ),
      ),
    );
  };

  // Configure logging for Supabase and other internal tools
  if (kDebugMode) {
    Logger.root.level = Level.ALL; // Log everything in debug mode
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: [${record.loggerName}] ${record.message}');
      if (record.error != null) debugPrint('Error: ${record.error}');
      if (record.stackTrace != null) debugPrint('StackTrace: ${record.stackTrace}');
    });
  }
  
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    debug: kDebugMode,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Required for deep-link email callback flow
    ),
  );

  final authState = AuthState();
  final router = createRouter(authState);
  
  runApp(
    ChangeNotifierProvider.value(
      value: authState,
      child: IeltsApp(router: router),
    ),
  );
}

class IeltsApp extends StatelessWidget {
  final GoRouter router;
  const IeltsApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IELTSPrep',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Dynamically toggle theme mode based on OS settings
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      routerConfig: router,
      builder: (context, child) {
        final auth = Provider.of<AuthState>(context);
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child!;
      },
    );
  }
}
