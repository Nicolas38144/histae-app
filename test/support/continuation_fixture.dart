import 'package:http/http.dart' as http;

import 'auth_fixture.dart';
import 'catalog_fixture.dart';
import 'matches_fixture.dart';

Map<String, dynamic> quotaJson({bool premium = false, int remaining = 2}) => {
  'plan': premium ? 'premium' : 'free',
  'used': premium ? 0 : 1,
  if (!premium) ...{'weekly_limit': 5, 'remaining': remaining},
  'weekly_credits': premium ? 0 : 2,
  'free_remaining': premium ? 0 : 1,
  'advertising_balance': 2,
  'advertising_remaining': premium ? 0 : 1,
  'reserved': 1,
  'advertising_stock_limit': 3,
};
const rewardId = '99999999-9999-4999-8999-999999999999';
Map<String, dynamic> rewardJson({String status = 'pending'}) => {
  'id': rewardId,
  'ad_unit': 'ca-app-pub-3940256099942544/5224354917',
  'custom_data': rewardId,
  'expires_at': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
  'status': status,
  'reward_credits': 1,
};
http.Response defaultContinuationResponse(http.Request r) =>
    switch (r.url.path) {
      '/api/plans' => jsonResponse(catalogJson()),
      '/api/users/me/continuation-quota' => jsonResponse(quotaJson()),
      '/api/matches/me' => jsonResponse({
        'matches': [publicMatchJson(status: 'awaiting_continuation')],
        'next_cursor': null,
      }),
      _ => defaultMatchesResponse(r),
    };
