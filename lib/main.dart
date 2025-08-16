import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickfix/quickFix.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]); 

  //Initialize firebase
  await FirebaseService.instance.initalize();

  //Initialize Google Ads
  await AdService.instance.initialize();
  print('Connected to Firebase app → ${Firebase.app().name}');

  runApp(const QuickFix());
}