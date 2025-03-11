import 'package:flutter/material.dart';
import 'package:flutter_progress_hud/flutter_progress_hud.dart';
import 'package:provider/provider.dart';

import 'providers/backup_provider.dart';
import 'screens/backup_screen.dart';

void main() => runApp(const BackupApp());

class BackupApp extends StatelessWidget {
  const BackupApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Envolve o app com o ChangeNotifierProvider para fornecer o BackupProvider a toda a árvore de widgets.
    return ChangeNotifierProvider(
      create: (context) => BackupProvider(),
      child: MaterialApp(
        title: 'Backup e Link Simbólico',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: ProgressHUD(
          child: const BackupScreen(),
        ),
      ),
    );
  }
}
