// Auto generated File
// DON'T EDIT BY HAND
//
// ...except here, deliberately. Upstream also exports phosphor_icons_base
// (the PhosphorIcons.acorn([style]) helper) plus the thin/light/duotone style
// classes. That base file is a ~36k-line runtime switch that hard-references
// all six style classes for every one of ~770 icons, so Flutter's const_finder
// sees every codepoint in every family as reachable and cannot tree-shake ANY
// Phosphor font - which is why the build log showed ~12% shaved off Phosphor
// while MaterialIcons got 99.5%.
//
// This app only ever uses PhosphorIconsRegular / Bold / Fill directly (checked:
// no references to PhosphorIcons.x(), PhosphorIcon, PhosphorIconsStyle, or the
// thin/light/duotone classes anywhere in lib/), so exporting just those three
// lets the icon tree-shaker do its job.
//
// The unexported sources are still on disk, untouched. To use another style,
// re-add its export here AND its font to this package's pubspec.yaml - and
// expect the tree-shaking win to shrink, since that is the trade being made.

export 'package:phosphor_flutter/src/phosphor_icons_regular.dart';
export 'package:phosphor_flutter/src/phosphor_icons_bold.dart';
export 'package:phosphor_flutter/src/phosphor_icons_fill.dart';
