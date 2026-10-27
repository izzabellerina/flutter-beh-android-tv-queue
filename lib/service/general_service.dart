import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/models/queue_calling_voice_text_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_type_model.dart';
import 'package:flutter_android_tv_queue/models/response_model.dart';
import 'package:flutter_android_tv_queue/models/voice_model.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/service/configuration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class GeneralService {
  static Future<ResponseModel<List<QueueConfigTypeModel>>>
  getAllQueueConfigType(BuildContext context, {http.Client? client}) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final login = container.read(loginProvider);

    final httpString = BehConfig.https(
      service: PortConfig.generalPort,
      path: "v3/queue-config-type/get-all-queue-config-type",
    );

    final uri = Uri.parse(httpString);
    final httpGetResponse = (client?.get ?? http.get)(
      uri,
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${login.token}',
      },
    );

    final response = await httpGetResponse;

    log("Response Body (getAllQueueConfigType) ${response.body}");
    log("Response Status Code (getAllQueueConfigType) ${response.statusCode}");

    if (response.statusCode == 200) {
      final responseJS = Map.from(jsonDecode(response.body));
      final list = List.from(responseJS['data'] ?? [])
          .map((e) => QueueConfigTypeModel(data: e))
          .toList();
      return ResponseModel(data: list, responseEnum: ResponseEnum.success);
    } else {
      return ResponseModel(data: [], responseEnum: ResponseEnum.fail);
    }
  }

  static Future<ResponseModel<List<QueueConfigModel>>> getAllQueueConfig(
    BuildContext context, {
    required int queueConfigTypeId,
    http.Client? client,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final login = container.read(loginProvider);

    final httpString = BehConfig.https(
      service: PortConfig.generalPort,
      path:
          "v3/queue-config/get-all-queue-config?queue_category=DEPARTMENT_QUEUE&queue_config_type_id=$queueConfigTypeId",
    );

    final uri = Uri.parse(httpString);
    final httpGetResponse = (client?.get ?? http.get)(
      uri,
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${login.token}',
      },
    );

    final response = await httpGetResponse;

    log("Response Body (getAllQueueConfig) ${response.body}");
    log("Response Status Code (getAllQueueConfig) ${response.statusCode}");

    if (response.statusCode == 200) {
      final responseJS = Map.from(jsonDecode(response.body));
      final list = List.from(responseJS['data'] ?? [])
          .map((e) => QueueConfigModel(data: e))
          .toList();
      return ResponseModel(data: list, responseEnum: ResponseEnum.success);
    } else {
      return ResponseModel(data: [], responseEnum: ResponseEnum.fail);
    }
  }

  static Future<ResponseModel<VoiceModel>> getVoice(
    BuildContext context, {
    required String textEn,
    required String textTh,
    required double speakingRate,
    http.Client? client,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final login = container.read(loginProvider);

    final httpString = BehConfig.https(
      service: PortConfig.generalPort,
      path: "v3/queue/get-voice",
    );

    final uri = Uri.parse(httpString);
    final httpPostResponse = (client?.post ?? http.post)(
      uri,
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${login.token}',
      },
      body: jsonEncode({
        "text_en": textEn,
        "text_th": textTh,
        "speaking_rate": speakingRate,
      }),
    );

    final response = await httpPostResponse;

    log("Response Body (getVoice) ${response.body}");
    log("Response Status Code (getVoice) ${response.statusCode}");

    if (response.statusCode == 200) {
      final responseJS = Map.from(jsonDecode(response.body));
      return ResponseModel(
        data: VoiceModel(data: responseJS['data'] ?? {}),
        responseEnum: ResponseEnum.success,
      );
    } else {
      return ResponseModel(
        data: VoiceModel(data: {}),
        responseEnum: ResponseEnum.fail,
      );
    }
  }

  static Future<ResponseModel<QueueCallingVoiceTextModel>>
  getLastOneQueueCallingVoiceText(
    BuildContext context, {
    http.Client? client,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final login = container.read(loginProvider);

    final httpString = BehConfig.https(
      service: PortConfig.generalPort,
      path: "v3/queue-calling-voice-text/get-last-one-queue-calling-voice-text",
    );

    final uri = Uri.parse(httpString);
    final httpGetResponse = (client?.get ?? http.get)(
      uri,
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${login.token}',
      },
    );

    final response = await httpGetResponse;

    log("Response Body (getLastOneQueueCallingVoiceText) ${response.body}");
    log(
      "Response Status Code (getLastOneQueueCallingVoiceText) ${response.statusCode}",
    );

    if (response.statusCode == 200) {
      final responseJS = Map.from(jsonDecode(response.body));
      return ResponseModel(
        data: QueueCallingVoiceTextModel(data: responseJS['data'] ?? {}),
        responseEnum: ResponseEnum.success,
      );
    } else {
      return ResponseModel(
        data: QueueCallingVoiceTextModel(data: {}),
        responseEnum: ResponseEnum.fail,
      );
    }
  }
}
