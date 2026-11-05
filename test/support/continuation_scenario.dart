import 'dart:convert';

import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:http/http.dart' as http;

import 'auth_fixture.dart';
import 'continuation_fixture.dart';
import 'matches_fixture.dart';
import 'rewarded_video_fixture.dart';

/// Synthetic server state shared by continuation checks and the video preview.
class ContinuationScenario {
  ContinuationScenario({
    this.premium = false,
    this.remaining = 2,
    this.advertising = 1,
    this.mine = false,
    this.partner = false,
    this.loseFirstResponse = false,
  }) {
    session = testSession(_reply);
    realtime = QuietRealtime(session);
    matches = MatchesController(MatchesRepository(session), realtime: realtime);
  }

  final bool premium;
  int remaining, advertising;
  bool mine, partner, loseFirstResponse;
  late final SessionController session;
  late final QuietRealtime realtime;
  late final MatchesController matches;
  final costs = <int>[];
  final responses = <String, Map<String, Object?>>{};
  int quotaReads = 0, historyReads = 0;
  bool _disposed = false;

  Future<void> start() async {
    await session.establish(testTokens);
    await matches.activate();
    await matches.openChat(testMatch);
    await matches.continuation.activate();
  }

  Map<String, dynamic> get match => {
    ...publicMatchJson(
      status: mine && partner ? 'confirmed' : 'awaiting_continuation',
    ),
    'my_continued': mine,
    'unread_count': 0,
    'other_user': {
      ...(publicMatchJson()['other_user'] as Map<String, dynamic>),
      'firstname': 'Elsa',
    },
  };

  Future<http.Response> _reply(http.Request request) async {
    if (responses[request.url.path] case final response?) {
      return jsonResponse(response);
    }
    if (request.url.path == '/api/plans') {
      return jsonResponse(rewardedCatalogJson());
    }
    if (request.url.path == '/api/matches/me') {
      return jsonResponse({
        'matches': [match],
        'next_cursor': null,
      });
    }
    if (request.url.path.endsWith('/continuation-quota')) {
      quotaReads++;
      return jsonResponse({
        ...quotaJson(premium: premium, remaining: remaining),
        'free_remaining': premium ? 0 : (remaining - advertising).clamp(0, 2),
        'advertising_balance': premium ? 0 : advertising,
        'advertising_remaining': premium ? 0 : advertising.clamp(0, remaining),
        'reserved': 0,
      });
    }
    if (request.url.path.endsWith('/continue')) {
      costs.add(
        (jsonDecode(request.body) as Map<String, dynamic>)['credit_cost']
            as int,
      );
      if (loseFirstResponse) {
        loseFirstResponse = false;
        remaining = 0;
        advertising = 0;
        return apiError(504, 'upstream_unavailable');
      }
      mine = true;
      if (!premium && remaining > 0) remaining--;
      return jsonResponse({'match_confirmed': mine && partner});
    }
    if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
      historyReads++;
      return jsonResponse({
        'messages': [
          messageJson(
            content: 'Ça me ferait plaisir de continuer cette discussion.',
            readAt: DateTime.now().toUtc().toIso8601String(),
          ),
          messageJson(
            id: outgoingId,
            sender: testUser,
            content: 'Moi aussi, il nous reste encore plein de choses à nous raconter !',
          ),
        ],
        'next_cursor': null,
      });
    }
    return defaultContinuationResponse(request);
  }

  void partnerContinues() {
    partner = true;
    realtime.emit(const MobileSignal('match.updated', matchId: testMatch));
  }

  void dispose({bool sessionAlreadyDisposed = false}) {
    if (_disposed) return;
    _disposed = true;
    matches.dispose();
    if (!sessionAlreadyDisposed) session.dispose();
  }
}
