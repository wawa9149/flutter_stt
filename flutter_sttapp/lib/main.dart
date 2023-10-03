import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

// 앱을 실행, 'MyApp' 위젯 실행
void main() {
  runApp(const MyApp());
}

// 앱의 기본 구조를 정의, 'MyHomePage' 위젯을 홈 화면으로 설정
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

// StatefulWidget 클래스를 상속
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// MyHomePage 위젯의 상태, 음성 인식을 위한 초기화 및 상태 관리
class _MyHomePageState extends State<MyHomePage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  // 음성 인식을 초기화하는 함수
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (error) => print('Error: $error'),
    );
    setState(() {});
  }

  // 음성 인식을 시작하는 함수, 10초 동안 음성 수집
  void _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 10), // 녹음 시간 설정
    );
    setState(() {});
  }

  // 음성 인식을 중지하는 함수
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  // 음성 인식 결과가 도착하면 호출되는 콜백 함수, _lastWords 변수에 저장
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Recognized words:',
                style: TextStyle(fontSize: 20.0),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _speechToText.isListening
                      ? _lastWords
                      : _speechEnabled
                          ? 'Tap the microphone to start listening...'
                          : 'Speech not available',
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _speechToText.isListening ? _stopListening : _startListening,
        tooltip: 'Listen',
        child: Icon(_speechToText.isListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.stop(); // 페이지를 벗어나기 전에 녹음 중지
    super.dispose();
  }
}
