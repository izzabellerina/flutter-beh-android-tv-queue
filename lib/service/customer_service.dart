import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/models/appointment_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_call_queue_model.dart';
import 'package:flutter_android_tv_queue/models/response_model.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/service/configuration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class CustomerService {
  static Future<ResponseModel<QueueConfigCallQueueModel>>
  getOneQueueConfigCallQueueByQueueType(
    BuildContext context, {
    required String queueType,
    required String date,
    http.Client? client,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final login = container.read(loginProvider);

    final httpString = BehConfig.https(
      service: PortConfig.customerPort,
      path:
          "v3/appointment/get-one-queue-config-call-queue-by-queue-type/$queueType/$date",
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

    log(
      "Response Body (getOneQueueConfigCallQueueByQueueType) ${response.body}",
    );
    log(
      "Response Status Code (getOneQueueConfigCallQueueByQueueType) ${response.statusCode}",
    );

    if (response.statusCode == 200) {
      final responseJS = Map.from(jsonDecode(response.body));
      return ResponseModel(
        data: QueueConfigCallQueueModel(data: responseJS['data'] ?? {}),
        responseEnum: ResponseEnum.success,
      );
    } else {
      return ResponseModel(
        data: QueueConfigCallQueueModel(data: {}),
        responseEnum: ResponseEnum.fail,
      );
    }
  }

  static Future<ResponseModel<List<AppointmentQueueModel>>>
  getAllAppointmentBookedDateByQueue(
    BuildContext context, {
    required String bookedDate,
    required String queuePrefix,
    required String callQueueStatus,
    http.Client? client,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final login = container.read(loginProvider);

    final httpString = BehConfig.https(
      service: PortConfig.customerPort,
      path:
          "v3/appointment/get-all-appointment-bookeddate-by-queue/$bookedDate?queue_prefix=$queuePrefix&has_visit=true&has_timeleft=false&call_queue_status=$callQueueStatus",
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

    log("Response Body (getAllAppointmentBookedDateByQueue) ${response.body}");
    log(
      "Response Status Code (getAllAppointmentBookedDateByQueue) ${response.statusCode}",
    );

    if (response.statusCode == 200) {
      final responseJS = Map.from(jsonDecode(response.body));
      final list = List.from(responseJS['data'] ?? [])
          .map((e) => AppointmentQueueModel(data: e))
          .toList();
      return ResponseModel(data: list, responseEnum: ResponseEnum.success);
    } else {
      return ResponseModel(data: [], responseEnum: ResponseEnum.fail);
    }
  }
}
