import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/LHomePage.dart';
import 'package:webrtc_demo_flutter/network/socket_io_client.dart';

void main() {
  // 应用自定义的 HTTP Overrides
  HttpOverrides.global = MyHttpOverrides();
  runApp(const LApp());
}
