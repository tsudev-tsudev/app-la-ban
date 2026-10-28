/// Chuỗi giao diện vi/en (ARB).
library;

import 'package:flutter/widgets.dart';
import 'package:i18n/src/gen/lb_l10n.dart';

export 'src/domain/ngon_ngu.dart';
export 'src/gen/lb_l10n.dart';

/// Lối tắt `context.l10n.xxx`.
extension LbL10nContext on BuildContext {
  LbL10n get l10n => LbL10n.of(this);
}
