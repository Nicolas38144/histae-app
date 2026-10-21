# Image de lancement iOS

Ce catalogue contient les trois échelles de `LaunchImage`, référencées par `Contents.json` et par `ios/Runner/Base.lproj/LaunchScreen.storyboard`.

Pour modifier l’image native, remplacer les variantes 1x, 2x et 3x en conservant leur cohérence avec le fond bleu nuit et le [système visuel Histae](../../../../DESIGN_SYSTEM.md). Sur macOS, ouvrir `ios/Runner.xcworkspace` dans Xcode pour contrôler le catalogue et le storyboard.

L’animation du nom et du livre est gérée séparément par `lib/app/app_opening.dart`. Vérifier le démarrage à froid sur appareil iOS après une modification native.
