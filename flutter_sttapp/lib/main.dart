import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

//import 'package:googleapis/speech/v1.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Recorder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late FlutterSoundPlayer _player;
  late FlutterSoundRecorder _recorder;
  bool _isRecording = false;
  late String _recordingPath;

  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer();
    _recorder = FlutterSoundRecorder();
    _recordingPath = '';
  }

  Future<void> _startRecording() async {
    try {
      String tempDir = (await getTemporaryDirectory()).path;
      String filePath = '$tempDir/temp_recording.aac';
      await _recorder.openRecorder();
      await _recorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecording = true;
        _recordingPath = filePath;
      });
      // ignore: empty_catches
    } catch (e) {}
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _playRecording() async {
    await _player.openPlayer();
    await _player.startPlayer(
      fromURI: _recordingPath,
      codec: Codec.aacADTS,
    );
  }

  @override
  void dispose() {
    _player.closePlayer();
    _recorder.closeRecorder();
    super.dispose();
  }

//   void transcribeAudio(String audioFilePath) async {
//     // 서비스 계정 키의 경로
//     const serviceAccountPath = 'path/to/your/service-account-key.json';

//     // 서비스 계정 로드
//     final serviceAccountCredentials =
//         ServiceAccountCredentials.fromJson(File(serviceAccountPath).readAsStringSync());

//     // Speech-to-Text API에 액세스하기 위한 사용자 인증
//     final client = await clientViaServiceAccount(serviceAccountCredentials, speech.SpeechApi.speechScope);

//     // Speech-to-Text API 클라이언트 생성
//     final speechApi = speech.SpeechApi(client);

//     // Speech Recognition 요청 구성
//     final config = speech.RecognitionConfig()
//       ..encoding = 'LINEAR16' // 오디오 인코딩 형식
//       ..sampleRateHertz = 16000 // 샘플 속도
//       ..languageCode = 'en-US'; // 언어 코드

//     // 오디오 파일에서 Speech Recognition 수행
//     final audioData = File(audioFilePath).readAsBytesSync();
//     final response = await speechApi.speech.recognize(
//       speech.SpeechRecognitionRequest()..config = config..audio = speech.SpeechRecognitionAudio()..content = audioData,
//     );

//     // 결과 출력
//     if (response.results != null && response.results!.isNotEmpty) {
//       final transcript = response.results!.first.alternatives!.first.transcript;
//       print('Transcription: $transcript');
//     } else {
//       print('No transcription results found.');
//     }

//     // 클라이언트 종료
//     client.close();
//   }
// }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Recorder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _isRecording
                ? ElevatedButton(
                    onPressed: _stopRecording,
                    //transcribeAudio('path/to/your/audio/file.wav'),

                    child: const Text('Stop Recording'),
                  )
                : ElevatedButton(
                    onPressed: _startRecording,
                    child: const Text('Start Recording'),
                  ),
            const SizedBox(height: 20),
            _recordingPath.isNotEmpty
                ? ElevatedButton(
                    onPressed: _playRecording,
                    child: const Text('Play Recording'),
                  )
                : Container(),
            const SizedBox(
              height: 20,
            ),
            const Text("녹음 내용")
          ],
        ),
      ),
    );
  }
}
