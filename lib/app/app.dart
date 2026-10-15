import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/l10n/app_strings.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/presentation/catalog_page.dart';
import 'theme.dart';

class HistaeApp extends StatefulWidget {
  const HistaeApp({super.key, this.catalogRepository});
  // Ownership is transferred to the app; requests close when it is disposed.
  final CatalogRepository? catalogRepository;

  @override
  State<HistaeApp> createState() => _HistaeAppState();
}

class _HistaeAppState extends State<HistaeApp> {
  @override
  void dispose() {
    widget.catalogRepository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: const AppStrings().appName,
    debugShowCheckedModeBanner: false,
    theme: histaeTheme(Brightness.light),
    darkTheme: histaeTheme(Brightness.dark),
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: _WelcomePage(repository: widget.catalogRepository),
  );
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.repository});
  final CatalogRepository? repository;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.appName)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.forum_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Semantics(
                  header: true,
                  child: Text(
                    strings.welcomeTitle,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  strings.welcomeBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/catalog'),
                      builder: (_) => CatalogPage(repository: repository),
                    ),
                  ),
                  child: Text(strings.catalogAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
