import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../profile/data/profile_models.dart';
import '../application/match_access.dart';

class PartnerPhotoPage extends StatefulWidget {
  const PartnerPhotoPage({
    super.key,
    required this.access,
    required this.matchId,
    this.photoClient,
  });
  final MatchAccess access;
  final String matchId;
  final http.Client Function()? photoClient;
  @override
  State<PartnerPhotoPage> createState() => _PartnerPhotoPageState();
}

class _PartnerPhotoPageState extends State<PartnerPhotoPage>
    with WidgetsBindingObserver {
  MatchAccess get c => widget.access;
  late final _key = c.session.resourceKey;
  ImageProvider? _image;
  String? _url, _error;
  http.Client? _client;
  Timer? _expiry;
  int _epoch = 0;
  bool _foreground = true, _loading = false;
  bool get _allowed =>
      _foreground &&
      c.active &&
      c.verified &&
      c.session.resourceKey == _key &&
      c.selected?.id == widget.matchId &&
      c.selected!.historyAllowed &&
      c.selected!.photosRevealed &&
      c.readAt != null &&
      DateTime.now().toUtc().difference(c.readAt!) < const Duration(minutes: 4);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          c.refresh().then((_) {
            if (mounted) _changed();
          }),
        );
      }
    });
  }

  void _purge() {
    _epoch++;
    _client?.close();
    _client = null;
    _expiry?.cancel();
    if (_image case final image?) unawaited(image.evict());
    _image = null;
    _url = null;
    _loading = false;
  }

  void _changed() {
    if (!mounted) return;
    final url = _allowed ? c.selected!.partner.photo : null;
    if (!_allowed || url == null) {
      setState(_purge);
      return;
    }
    if (url == _url) return;
    _purge();
    _url = url;
    _error = null;
    _expiry = Timer(const Duration(minutes: 4), () {
      if (!mounted) return;
      setState(_purge);
      unawaited(c.refresh());
    });
    unawaited(_fetch(url));
  }

  Future<void> _fetch(String url) async {
    if (!validPhotoUrl(url) || !_allowed) return;
    final epoch = _epoch, client = widget.photoClient?.call() ?? http.Client();
    _client = client;
    setState(() {
      _loading = true;
    });
    try {
      final task = () async {
        final response = await client.send(
          http.Request('GET', Uri.parse(url))..followRedirects = false,
        );
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > 5000000) {
          throw const FormatException('Unavailable photo');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 5000000) {
            throw const FormatException('Invalid photo');
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      }();
      final bytes = await task.timeout(const Duration(seconds: 15));
      if (mounted && epoch == _epoch && _allowed && _url == url) {
        setState(() {
          _image = ResizeImage(MemoryImage(bytes), width: 1024);
        });
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = 'La photo temporaire n’est pas disponible. Actualisez pour obtenir un nouveau lien.';
        });
      }
    } finally {
      client.close();
      if (mounted && epoch == _epoch) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      setState(_purge);
    } else {
      unawaited(c.refresh());
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _purge();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Une photo, à deux')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!_allowed || c.selected?.partner.photo == null)
            const Text('Cette photo n’est pas disponible actuellement.')
          else ...[
            if (_loading)
              const LinearProgressIndicator(
                semanticsLabel: 'Chargement de la photo',
              ),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image(
                    image: _image!,
                    fit: BoxFit.contain,
                    semanticLabel: 'Photo de votre rencontre',
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'La photo ne peut pas être affichée. Actualisez le lien temporaire.',
                      ),
                    ),
                  ),
                ),
              ),
            if (_error != null) Text(_error!),
            const SizedBox(height: 24),
            const Text(
              'Vos accords de révélation sont mutuels. Les photos restent absentes du feed.',
            ),
          ],
          OutlinedButton.icon(
            onPressed: !c.active || _loading
                ? null
                : () async {
                    setState(_purge);
                    await c.refresh();
                    if (mounted) _changed();
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Actualiser la photo'),
          ),
        ],
      ),
    ),
  );
}
