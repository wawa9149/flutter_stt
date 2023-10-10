import 'package:flutter/material.dart';
import 'package:flutter_sttapp/demo/recording.dart' as recording;

void main() {
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyPage(),
    );
  }
}

class MyPage extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        title:const Text('Speech To Text'),
      ),
      body: const Center(
        child: recording.Recording(),// Column
      ),	// Cen
    );
  }
}