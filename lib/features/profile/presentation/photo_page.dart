import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/profile_controller.dart';
import '../data/photo_preparer.dart';
import '../data/profile_models.dart';
import 'profile_strings.dart';

class PhotoPage extends StatefulWidget {
  const PhotoPage({
    super.key,
    required this.controller,
    this.preparer,
    this.photoClient,
  });
  final ProfileController controller;
  final PhotoPreparer? preparer;
  final PhotoClientFactory? photoClient;
  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> with WidgetsBindingObserver {
  ProfileController get c => widget.controller;
  late final preparer = widget.preparer ?? PhotoPreparer();
  late final String _ownerScope = c.session.resourceKey;
  Uint8List? _remote;
  String? _url, _message;
  DateTime? _readAt;
  SignedPhotoDownload? _download;
  Timer? _expiry;
  bool _choosing = false, _fetching = false, _active = true;
  int _downloadGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    unawaited(_recover());
    unawaited(
      c.load().then((_) {
        if (mounted) _changed();
      }),
    );
  }

  Future<void> _recover() async {
    try {
      if (await preparer.discardInterruptedSelection() && mounted) {
        setState(() {
          _message = 'Une sélection a été interrompue. Choisissez à nouveau votre photo pour ce compte.';
        });
      }
    } catch (_) {
      /* Selection still works if Android recovery is unavailable. */
    }
  }

  void _purgeRemote() {
    _downloadGeneration++;
    _download?.cancel();
    _download = null;
    if (_remote case final bytes?) unawaited(MemoryImage(bytes).evict());
    _remote = null;
    _url = null;
    _readAt = null;
    _fetching = false;
    _expiry?.cancel();
  }

  void _changed() {
    if (!mounted) return;
    if (!c.accessible || c.session.resourceKey != _ownerScope) {
      setState(_purgeRemote);
      return;
    }
    if (!_active) return;
    if (c.loading) {
      setState(() {});
      return;
    }
    final url = c.profile?.photo;
    if (url != _url || c.photoReadAt != _readAt) {
      _purgeRemote();
      _url = url;
      _readAt = c.photoReadAt;
      // Owner URLs last 300 s in the server contract. Refresh before expiry,
      // including when the signer happens to return the same URL.
      final age = DateTime.now().difference(
        _readAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
      final remaining = const Duration(minutes: 4) - age;
      if (remaining > Duration.zero && url != null) {
        _expiry = Timer(remaining, () {
          if (mounted) {
            setState(_purgeRemote);
            unawaited(c.load());
          }
        });
        unawaited(_fetch(url));
      }
    }
    setState(() {});
  }

  Future<void> _fetch(String url) async {
    if (!validPhotoUrl(url)) return;
    final generation = _downloadGeneration;
    final request = SignedPhotoLoader(clientFactory: widget.photoClient)
        .load(url);
    _download = request;
    _fetching = true;
    try {
      final bytes = await request.bytes;
      if (mounted &&
          _active &&
          generation == _downloadGeneration &&
          c.accessible &&
          c.session.resourceKey == _ownerScope) {
        setState(() {
          _remote = bytes;
        });
      }
    } catch (_) {
      if (mounted && generation == _downloadGeneration) {
        setState(() {
          _message = 'L’aperçu temporaire n’est pas disponible. Actualisez pour obtenir un nouveau lien.';
        });
      }
    } finally {
      request.cancel();
      if (mounted && generation == _downloadGeneration) {
        setState(() {
          _fetching = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      setState(_purgeRemote);
    } else {
      unawaited(
        c.load().then((_) {
          if (mounted) _changed();
        }),
      );
    }
  }

  Future<void> _choose() async {
    if (_choosing || !c.canWrite) return;
    if (c.photoIntent != null &&
        !await confirmAction(
          context,
          'Changer la sélection ?',
          'La demande photo en mémoire sera abandonnée.',
          action: 'Choisir une autre photo',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _choosing = true;
      _message = null;
    });
    try {
      final bytes = await preparer.choose();
      if (mounted &&
          c.accessible &&
          c.session.resourceKey == _ownerScope &&
          bytes != null) {
        c.setPhoto(bytes);
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _message = ProfileStrings.failure(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _choosing = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    try {
      await c.upload();
      if (mounted) {
        setState(() {
          _message =
              'Photo reçue. Son état de vérification est affiché ci-dessous.';
        });
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _message = ProfileStrings.failure(e);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    _purgeRemote();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible || c.session.resourceKey != _ownerScope) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final intent = c.photoIntent;
      final preview = intent == null ? _remote : intent.bytes;
      return HistaeScaffold(
        appBar: AppBar(title: const Text('Votre photo')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Un visage,\nau bon moment.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              const Text(
                'Une seule photo personnelle. Elle n’apparaît pas dans le feed et sa révélation demandera votre accord mutuel.',
              ),
              const SizedBox(height: 24),
              if (preview != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.memory(
                    preview,
                    height: 320,
                    fit: BoxFit.contain,
                    semanticLabel: intent == null ? 'Votre photo actuelle' : 'Votre sélection, pas encore confirmée par le serveur',
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 120,
                      child: Center(child: Text('Aperçu non disponible')),
                    ),
                  ),
                ),
              if (_fetching || _choosing || c.saving || c.loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Préparation ou chargement de la photo',
                ),
              if (c.profile?.photo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Photo actuelle : ${ProfileStrings.moderation(c.profile!.photoModeration)}',
                  ),
                ),
              if (intent != null)
                Text(
                  'Sélection préparée : ${intent.bytes.length} octets. Elle remplacera votre photo actuelle après envoi.',
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Semantics(liveRegion: true, child: Text(_message!)),
                ),
              if (c.uncertain)
                const Text(
                  'L’envoi peut avoir abouti. Reprendre conserve exactement la même photo et la même demande. Aucun renvoi automatique.',
                ),
              if (c.retrySeconds > 0)
                Text('Nouvel essai possible dans ${c.retrySeconds} s'),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: !c.canWrite || _choosing ? null : _choose,
                child: Text(
                  intent == null && c.profile?.photo == null
                      ? 'Choisir une photo'
                      : 'Choisir une autre photo',
                ),
              ),
              if (intent != null) ...[
                const SizedBox(height: 12),
                HistaeButton(
                  onPressed:
                      _choosing || c.saving || c.loading || c.retrySeconds > 0
                      ? null
                      : _upload,
                  child: const Text('Envoyer ou reprendre cette photo'),
                ),
              ],
              TextButton(
                onPressed: c.loading || c.saving || c.retrySeconds > 0
                    ? null
                    : () async {
                        _purgeRemote();
                        await c.load();
                        if (mounted) _changed();
                      },
                child: const Text('Actualiser la photo et son état'),
              ),
              if (c.profile?.photo != null)
                TextButton(
                  onPressed: !c.canWrite || _choosing
                      ? null
                      : () async {
                          if (!await confirmAction(
                                context,
                                'Retirer votre photo ?',
                                'La photo ne sera plus disponible. Le nettoyage du stockage se poursuivra en arrière-plan.',
                                action: 'Retirer la photo',
                              ) ||
                              !mounted) {
                            return;
                          }
                          try {
                            await c.removePhoto();
                          } on ApiFailure catch (e) {
                            if (mounted) {
                              setState(() {
                                _message = ProfileStrings.failure(e);
                              });
                            }
                          }
                        },
                  child: const Text('Retirer ma photo'),
                ),
            ],
          ),
        ),
      );
    },
  );
}
