// Real app screens, synthetic profiles and exchanges, no production requests.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/consents/presentation/consents_page.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/discovery_fixture.dart';
import '../test/support/matches_fixture.dart';
import '../test/support/profile_fixture.dart';
import '../test/support/rewarded_video_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Inter', 'inter/Inter-Variable.ttf'),
      ('SourceSerif4', 'source_serif_4/SourceSerif4-Variable.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
    final bytes = await File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  const copy = {
    'fr': [
      'Je suis le genre de personne qui entre dans une librairie pour cinq minutes et en ressort une heure plus tard. J’aime les romans dont on reparle longtemps, les cafés qui deviennent des habitudes et les promenades où l’on change trois fois de direction.\n\nEn semaine, je prends plaisir à cuisiner pour mes amis, même quand la recette part un peu de travers. Le dimanche, vous me trouverez souvent sur un sentier, un appareil photo dans le sac et quelque chose à partager pour le goûter.\n\nJ’aimerais rencontrer quelqu’un de curieux, avec qui passer des discussions très sérieuses aux blagues les plus absurdes. Racontez-moi un endroit où vous retournez toujours, ou le petit projet qui vous occupe en ce moment. Je préfère une réponse sincère à une phrase parfaite.',
      'Votre dimanche idéal ?',
      'Un café, un livre et une promenade sans itinéraire.',
      'Curieuse',
      'Attentionnée',
      'Contemplative',
      'Si vous pouviez partir demain, ce serait où ?',
      'Au bord de la mer, avec un livre et sans programme.',
      'Je vous rejoins pour le livre. Vous lisez quoi en ce moment ?',
      'J’aime les maisons pleines de livres et les tables où l’on reste après le dessert. Je peux passer une soirée à refaire le monde, puis avoir besoin d’une matinée tranquille à marcher sans regarder l’heure.\n\nCes derniers temps, j’apprends à reconnaître les oiseaux et à faire du pain. Les deux demandent une patience que je n’ai pas toujours, mais les progrès me font sourire. Je cherche une rencontre dans laquelle chacun garde sa place, ses amis et ses envies, avec le plaisir de se retrouver pour se raconter tout ça.',
    ],
    'en': [
      'I’m the sort of person who pops into a bookshop for five minutes and leaves an hour later. I love novels you keep talking about, cafés that become familiar places and walks where you change direction three times.\n\nDuring the week I enjoy cooking for friends, even when the recipe takes an unexpected turn. On Sundays you’ll often find me on a trail, with a camera in my bag and something to share for a picnic.\n\nI’d like to meet someone curious, someone who can go from a serious conversation to the most ridiculous jokes. Tell me about a place you always return to, or the little project keeping you busy lately. I’d rather hear an honest answer than a perfect line.',
      'Your perfect Sunday?',
      'Coffee, a book and a walk with no route in mind.',
      'Curious',
      'Thoughtful',
      'Reflective',
      'If you could leave tomorrow, where would you go?',
      'Somewhere by the sea, with a book and no plans.',
      'I’m with you on the book. What are you reading at the moment?',
      'I love houses full of books and tables where everyone lingers after dessert. I can spend an evening putting the world to rights, then need a quiet morning walking without checking the time.\n\nLately I’ve been learning to recognise birds and bake bread. Both take patience I don’t always have, but the progress makes me smile. I’m hoping for a connection where we each keep our own space, friends and interests, and enjoy coming back together to share our stories.',
    ],
    'es': [
      'Soy de esas personas que entran en una librería cinco minutos y salen una hora después. Me gustan las novelas de las que seguimos hablando, los cafés que se vuelven costumbre y los paseos en los que cambiamos de dirección tres veces.\n\nEntre semana disfruto cocinando para mis amigos, incluso cuando la receta toma un rumbo inesperado. Los domingos suelo estar en algún sendero, con una cámara en la mochila y algo para compartir en la merienda.\n\nMe gustaría conocer a alguien curioso, con quien pasar de una charla muy seria a las bromas más absurdas. Cuéntame un lugar al que siempre vuelves o ese pequeño proyecto que te ocupa últimamente. Prefiero una respuesta sincera a una frase perfecta.',
      '¿Tu domingo ideal?',
      'Un café, un libro y un paseo sin itinerario.',
      'Curiosa',
      'Atenta',
      'Reflexiva',
      'Si pudieras irte mañana, ¿adónde irías?',
      'A la orilla del mar, con un libro y sin planes.',
      'Me apunto a lo del libro. ¿Qué estás leyendo ahora?',
      'Me gustan las casas llenas de libros y las mesas donde seguimos charlando después del postre. Puedo pasar una noche arreglando el mundo y necesitar después una mañana tranquila, paseando sin mirar la hora.\n\nÚltimamente estoy aprendiendo a reconocer pájaros y a hacer pan. Ambas cosas requieren una paciencia que no siempre tengo, pero los avances me hacen sonreír. Busco una relación en la que cada uno conserve su espacio, sus amigos y sus inquietudes, con ganas de reencontrarnos para contárnoslo todo.',
    ],
    'it': [
      'Sono il tipo di persona che entra in libreria per cinque minuti e ne esce un’ora dopo. Amo i romanzi di cui si continua a parlare, i caffè che diventano abitudini e le passeggiate in cui si cambia direzione tre volte.\n\nDurante la settimana mi piace cucinare per gli amici, anche quando la ricetta prende una piega imprevista. La domenica mi trovate spesso su un sentiero, con una macchina fotografica nello zaino e qualcosa da condividere a merenda.\n\nVorrei conoscere una persona curiosa, con cui passare da discorsi serissimi alle battute più assurde. Raccontatemi un posto in cui tornate sempre, oppure il piccolo progetto che vi tiene occupati ultimamente. Preferisco una risposta sincera a una frase perfetta.',
      'La tua domenica ideale?',
      'Un caffè, un libro e una passeggiata senza itinerario.',
      'Curiosa',
      'Premurosa',
      'Riflessiva',
      'Se potessi partire domani, dove andresti?',
      'In riva al mare, con un libro e senza programmi.',
      'Per il libro ci sto. Cosa stai leggendo in questo periodo?',
      'Mi piacciono le case piene di libri e le tavole dove si resta a chiacchierare dopo il dolce. Posso passare una serata a parlare dei massimi sistemi e poi aver bisogno di una mattina tranquilla, camminando senza guardare l’ora.\n\nUltimamente sto imparando a riconoscere gli uccelli e a fare il pane. Entrambe le cose richiedono una pazienza che non sempre ho, ma i progressi mi fanno sorridere. Cerco un incontro in cui ognuno conservi i propri spazi, amici e passioni, con il piacere di ritrovarsi per raccontarsi tutto.',
    ],
  };

  testWidgets('export localized app screenshots for the website', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in copy.keys) {
      final text = copy[language]!;
      final consentState = consentJson(
        complete: true,
        grants: {ConsentType.sensitive: true, ConsentType.location: true},
      );
      consentState['consents'] = [
        for (final document in consentState['consents'] as List<dynamic>)
          {
            ...document as Map<String, dynamic>,
            // The published legal documents are dated 26 October 2026.
            'document_date': '2026-10-26',
            'document_language': language,
            'accepted_document_language': language,
          },
      ];
      Map<String, dynamic> message({
        required String id,
        required String sender,
        required String content,
        required int minute,
        bool read = false,
      }) => {
        ...messageJson(id: id, sender: sender, content: content),
        'created_at': DateTime.utc(2026, 10, 27, 10, minute).toIso8601String(),
        'read_at': read
            ? DateTime.utc(2026, 10, 27, 10, minute + 1).toIso8601String()
            : null,
      };
      final messages = [
        message(id: outgoingId, sender: testUser, content: text[8], minute: 34),
        message(
          id: incomingId,
          sender: candidateOne,
          content: text[7],
          minute: 32,
        ),
        message(
          id: secondMatch,
          sender: testUser,
          content: text[6],
          minute: 30,
          read: true,
        ),
      ];
      Map<String, dynamic> candidate() => {
        ...candidateJson(candidateOne, bio: text[0]),
        'traits': text.sublist(3, 6),
        'profile_answers': [
          {
            'question_id': questionOne,
            'code': 'sunday',
            'question': text[1],
            'answer': text[2],
            'position': 0,
          },
        ],
      };
      final session = testSession((r) async {
        return switch (r.url.path) {
          '/api/users/me/consents' => jsonResponse(consentState),
          '/api/users/me' => jsonResponse(ownerJson(bio: text[9])),
          '/api/feed' => jsonResponse({
            'profiles': [candidate()],
            'next_cursor': null,
          }),
          '/api/traits' || '/api/users/me/traits' => jsonResponse({
            'traits': [
              {'id': traitOne, 'name': text[3]},
            ],
          }),
          '/api/profile-questions' => jsonResponse({
            'questions': [questionJson(questionOne, text[1], 0)],
          }),
          '/api/users/me/profile-answers' => jsonResponse({
            'answers': [
              {
                ...answerJson(questionOne, text[2], 0),
                'question': text[1],
                'moderation_status': 'approved',
              },
            ],
          }),
          '/api/matches/me' => jsonResponse({
            'matches': [
              {
                ...publicMatchJson(),
                'other_user': {...candidate(), 'photo': null},
                'unread_count': 0,
                'last_message': messages.first,
              },
            ],
            'next_cursor': null,
          }),
          '/api/matches/$testMatch/messages' => jsonResponse({
            'messages': messages,
            'next_cursor': null,
          }),
          '/api/plans' => jsonResponse(rewardedCatalogJson()),
          _ => defaultContinuationResponse(r),
        };
      });
      await session.establish(testTokens);
      final locale = LocaleController();
      await locale.select(language);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('website-preview'),
          child: HistaeApp(
            localeController: locale,
            sessionController: session,
            rewardedVideoGateway: FakeRewardedVideoGateway(),
          ),
        ),
      );
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/branding/histae-signature-dark.png'),
            tester.element(find.byType(HistaeApp)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('website-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file = File('build/previews/website/$language/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
        });
        debugPrint('Exported $language/$name');
      }

      await capture('feed');
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await capture('profile');
      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      final matches = tester
          .widget<MatchesPage>(find.byType(MatchesPage))
          .controller;
      Future<void> show(Widget page, String name) async {
        unawaited(
          Navigator.of(tester.element(find.byType(MatchesPage)))
              .push(MaterialPageRoute<void>(builder: (_) => page)),
        );
        await capture(name);
        Navigator.of(tester.element(find.byType(page.runtimeType))).pop();
        await tester.pumpAndSettle();
      }

      await matches.openChat(testMatch);
      await show(ChatPage(controller: matches, matchId: testMatch), 'chat');
      await show(CreditsPage(controller: matches.continuation), 'credits');
      await show(ConsentsPage(session: session), 'privacy');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
