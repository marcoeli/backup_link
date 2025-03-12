import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_progress_hud/flutter_progress_hud.dart';
import 'package:provider/provider.dart';

import 'providers/backup_provider.dart';
import 'screens/backup_screen.dart';
import 'utils/localization.dart';

void main() => runApp(const BackupApp());

class BackupApp extends StatelessWidget {
  const BackupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BackupProvider(),
      child: MaterialApp(
        title: 'Backup e Link Simbólico',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''), // Inglês
          Locale('pt', ''), // Português
          Locale('es', ''), // Espanhol
        ],
        home: ProgressHUD(
          child: const BackupScreen(),
        ),
      ),
    );
  }
}
