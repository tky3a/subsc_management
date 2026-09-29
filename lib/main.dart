import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app_state.dart';
import 'data/app_database.dart';
import 'data/repository.dart';
import 'theme/app_theme.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final schemaSql = await rootBundle.loadString(AppDatabase.schemaAsset);
  final db = await AppDatabase.open(
    factory: databaseFactory,
    path: p.join(await getDatabasesPath(), AppDatabase.fileName),
    schemaSql: schemaSql,
  );
  final state = AppState(SubscriptionRepository(db));
  await state.refresh();

  runApp(SubscApp(state: state));
}

class SubscApp extends StatelessWidget {
  const SubscApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'サブスク管理',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ja'),
        home: const HomeShell(),
      ),
    );
  }
}
