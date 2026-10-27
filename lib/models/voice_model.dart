class VoiceModel {
  final Map data;

  VoiceModel({required this.data});

  String get audioContent => data['audio_content'] ?? '';

  String get audioEncoding => data['audio_encoding'] ?? '';
}
