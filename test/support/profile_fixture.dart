import 'package:http/http.dart' as http;

import 'auth_fixture.dart';

const questionOne = '22222222-2222-4222-8222-222222222222';
const questionTwo = '33333333-3333-4333-8333-333333333333';
const traitOne = '44444444-4444-4444-8444-444444444444';
Map<String, dynamic> ownerJson({
  String? sex = 'female',
  String? bio = 'Les livres, les sentiers et les dimanches sans réveil.',
  String? photo,
}) => {
  'user_id': testUser,
  'firstname': 'Camille',
  'birthdate': '1995-06-12',
  'sex': ?sex,
  'bio': ?bio,
  'photo': ?photo,
  'profile_answers': <Object?>[],
  'moderation': {
    'bio': {'status': 'approved', 'reasons': <Object?>[]},
    'photo': null,
  },
};
Map<String, dynamic> preferencesJson() => {
  'user_id': testUser,
  'min_age': 25,
  'max_age': 38,
  'max_distance_km': 40,
  'looking_for': 'both',
};
Map<String, dynamic> questionJson(String id, String prompt, int order) => {
  'id': id,
  'code': 'question_$order',
  'prompt': prompt,
  'category': 'daily_life',
  'display_order': order,
};
Map<String, dynamic> answerJson(String id, String text, int position) => {
  'question_id': id,
  'code': 'question_$position',
  'question': 'Votre dimanche idéal ?',
  'answer': text,
  'position': position,
  'moderation_status': 'pending',
  'moderation_reasons': <Object?>[],
};
http.Response defaultProfileResponse(http.Request request) =>
    switch (request.url.path) {
      '/api/users/me/discovery-settings' => jsonResponse({'paused': false}),
      '/api/users/me' => jsonResponse(ownerJson()),
      '/api/users/me/profile' => jsonResponse({'message': 'profile updated'}),
      '/api/users/me/preferences' =>
        request.method == 'GET'
            ? jsonResponse(preferencesJson())
            : jsonResponse({'message': 'preferences updated'}),
      '/api/traits' || '/api/users/me/traits' =>
        request.method == 'GET'
            ? jsonResponse({
                'traits': [
                  {'id': traitOne, 'name': 'Curieux'},
                ],
              })
            : http.Response('', 204),
      '/api/profile-questions' => jsonResponse({
        'questions': [
          questionJson(questionOne, 'Votre dimanche idéal ?', 1),
          questionJson(questionTwo, 'Ce qui vous fait sourire ?', 2),
        ],
      }),
      '/api/users/me/profile-answers' => jsonResponse({'answers': <Object?>[]}),
      '/api/users/me/photo' =>
        request.method == 'DELETE'
            ? http.Response('', 204)
            : jsonResponse({
                'message': 'photo updated',
                'photo': 'https://storage.example/owner?signature=synthetic',
                'moderation_status': 'approved',
                'moderation_reasons': <Object?>[],
              }),
      _ when request.url.path.startsWith('/api/users/me/traits/') =>
        http.Response('', 204),
      _ => defaultAuthResponse(request, complete: true),
    };
