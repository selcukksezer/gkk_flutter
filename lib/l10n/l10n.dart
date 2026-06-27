import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Resolves a localized string outside [BuildContext] (e.g. providers).
AppLocalizations lookupL10n(BuildContext context) => AppLocalizations.of(context);
