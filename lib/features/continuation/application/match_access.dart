import 'package:flutter/foundation.dart';

import '../../auth/domain/authenticated_session.dart';
import '../../matches/data/match_models.dart';

abstract interface class MatchAccess implements Listenable {
  AuthenticatedSession get session;
  bool get active;
  bool get verified;
  bool get ending;
  UserMatch? get selected;
  String? get selectedId;
  DateTime get serverNow;
  DateTime? get readAt;
  int get readRevision;
  int get privacyEpoch;
  int get privateRevision;
  bool isRemoved(String id);
  Future<void> refresh();
  void removeUnavailable(String id);
}
