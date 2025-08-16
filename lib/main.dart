import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickfix/app.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]); 

  //Initalize firebase
  await FirebaseService.instance.initalize();

  //Initalize Google Ads
  await AdService.instance.initialize();

  runApp(const QuickFix());
}