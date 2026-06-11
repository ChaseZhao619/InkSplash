import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'src/ink_splash_app.dart';

export 'src/ink_splash_app.dart';

void main() {
  assert(() {
    debugPaintSizeEnabled = false;
    debugPaintBaselinesEnabled = false;
    debugPaintPointersEnabled = false;
    debugRepaintRainbowEnabled = false;
    debugProfilePaintsEnabled = false;
    return true;
  }());
  runApp(const InkSplashApp());
}
