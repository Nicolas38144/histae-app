import 'dart:convert';

import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';

Never invalidProfile() =>
    throw const ApiFailure(ApiFailureKind.invalidResponse);

String? optionalText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) invalidProfile();
  return value as String?;
}

String serverId(Map<String, dynamic> json, String key) {
  final id = jsonString(json, key);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id)) {
    invalidProfile();
  }
  return id;
}

class Moderation {
  Moderation(this.status, this.reasons);
  factory Moderation.fromJson(Object? value) {
    final j = jsonObject(value);
    return Moderation.parse(jsonString(j, 'status'), j['reasons']);
  }
  factory Moderation.parse(String status, Object? reasons) {
    if (!['pending', 'approved', 'rejected'].contains(status) ||
        reasons is! List ||
        reasons.any((r) => r is! String)) {
      invalidProfile();
    }
    return Moderation(status, List<String>.unmodifiable(reasons));
  }
  final String status;
  final List<String> reasons;
}

class OwnerProfile {
  OwnerProfile(
    this.userId,
    this.firstname,
    this.birthdate,
    this.sex,
    this.bio,
    this.photo,
    this.bioModeration,
    this.photoModeration,
  );
  factory OwnerProfile.fromJson(Object? value) {
    final j = jsonObject(value);
    final m = jsonObject(j['moderation']);
    final birth = jsonString(j, 'birthdate');
    if (parseBirthdate(birth) == null) invalidProfile();
    final sex = optionalText(j, 'sex');
    if (sex != null && !['male', 'female', 'other'].contains(sex)) {
      invalidProfile();
    }
    final photo = optionalText(j, 'photo');
    if (photo != null && !validPhotoUrl(photo)) invalidProfile();
    jsonField<List<dynamic>>(j, 'profile_answers');
    return OwnerProfile(
      serverId(j, 'user_id'),
      jsonString(j, 'firstname'),
      birth,
      sex,
      optionalText(j, 'bio'),
      photo,
      m['bio'] == null ? null : Moderation.fromJson(m['bio']),
      m['photo'] == null ? null : Moderation.fromJson(m['photo']),
    );
  }
  final String userId, firstname, birthdate;
  final String? sex, bio, photo;
  final Moderation? bioModeration, photoModeration;
}

bool validPhotoUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment;
}

DateTime? parseBirthdate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final d = DateTime.tryParse('${value}T00:00:00Z');
  return d != null && d.toIso8601String().startsWith(value) ? d : null;
}

String? validateBirthdate(String value, DateTime now) {
  final d = parseBirthdate(value);
  if (d == null) return 'Indiquez une date valide au format AAAA-MM-JJ.';
  final today = now.toUtc();
  var age = today.year - d.year;
  if (today.month < d.month || (today.month == d.month && today.day < d.day)) {
    age--;
  }
  return age < 18
      ? 'Histae est réservé aux personnes de 18 ans et plus.'
      : null;
}

class ProfileDraft {
  const ProfileDraft(this.firstname, this.birthdate, this.sex, this.bio);
  final String firstname, birthdate;
  final String? sex, bio;
  String? validate(DateTime now) {
    if (firstname.trim().isEmpty ||
        utf8.encode(firstname.trim()).length > 100) {
      return 'Le prénom est obligatoire (100 octets maximum).';
    }
    final dateError = validateBirthdate(birthdate, now);
    if (dateError != null) return dateError;
    if (sex != null && !['male', 'female', 'other'].contains(sex)) {
      return 'Choisissez une valeur proposée.';
    }
    if (bio != null && utf8.encode(bio!.trim()).length > 2000) {
      return 'La présentation dépasse 2 000 octets.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'firstname': firstname.trim(),
    'birthdate': birthdate,
    'sex': sex,
    'bio': bio?.trim(),
  }; // Both nullable fields are intentionally sent.
}

class Preferences {
  const Preferences(this.minAge, this.maxAge, this.distance, this.lookingFor);
  factory Preferences.fromJson(Object? value) {
    final j = jsonObject(value);
    serverId(j, 'user_id');
    final p = Preferences(
      jsonField<int>(j, 'min_age'),
      jsonField<int>(j, 'max_age'),
      jsonField<int>(j, 'max_distance_km'),
      jsonString(j, 'looking_for'),
    );
    if (p.validate() != null) invalidProfile();
    return p;
  }
  final int minAge, maxAge, distance;
  final String lookingFor;
  String? validate() {
    if (minAge < 18 || maxAge > 99 || minAge > maxAge) {
      return 'Les âges doivent aller de 18 à 99 ans, dans cet ordre.';
    }
    if (distance < 1 || distance > 500) {
      return 'La distance doit aller de 1 à 500 km.';
    }
    if (!['male', 'female', 'both', 'other'].contains(lookingFor)) {
      return 'Choisissez les personnes que vous souhaitez rencontrer.';
    }
    return null;
  }

  Map<String, Object> toJson() => {
    'min_age': minAge,
    'max_age': maxAge,
    'max_distance_km': distance,
    'looking_for': lookingFor,
  };
}

class ProfileTrait {
  const ProfileTrait(this.id, this.name);
  factory ProfileTrait.fromJson(Object? value) {
    final j = jsonObject(value);
    return ProfileTrait(serverId(j, 'id'), jsonString(j, 'name'));
  }
  final String id, name;
}

class ProfileQuestion {
  const ProfileQuestion(
    this.id,
    this.code,
    this.prompt,
    this.category,
    this.order,
  );
  factory ProfileQuestion.fromJson(Object? value) {
    final j = jsonObject(value);
    return ProfileQuestion(
      serverId(j, 'id'),
      jsonString(j, 'code'),
      jsonString(j, 'prompt'),
      jsonString(j, 'category'),
      jsonField<int>(j, 'display_order'),
    );
  }
  final String id, code, prompt, category;
  final int order;
}

class ProfileAnswer {
  const ProfileAnswer(
    this.questionId,
    this.question,
    this.answer,
    this.position,
    this.moderation,
  );
  factory ProfileAnswer.fromJson(Object? value) {
    final j = jsonObject(value);
    jsonString(j, 'code');
    return ProfileAnswer(
      serverId(j, 'question_id'),
      jsonString(j, 'question'),
      jsonString(j, 'answer'),
      jsonField<int>(j, 'position'),
      Moderation.parse(
        jsonString(j, 'moderation_status'),
        j['moderation_reasons'],
      ),
    );
  }
  final String questionId, question, answer;
  final int position;
  final Moderation moderation;
}

class AnswerDraft {
  const AnswerDraft(this.questionId, this.answer);
  final String questionId, answer;
  Map<String, String> toJson() => {
    'question_id': questionId,
    'answer': answer.trim(),
  };
  String? validate() {
    final text = answer.trim();
    if (text.runes.length < 10 ||
        text.runes.length > 300 ||
        utf8.encode(text).length > 1000 ||
        text.runes.any((c) => c < 32 || (c >= 127 && c <= 159))) {
      return 'Chaque réponse doit contenir de 10 à 300 caractères, sur une ligne (1 000 octets maximum).';
    }
    return null;
  }
}
