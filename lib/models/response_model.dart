class ResponseModel<T> {
  final T data;
  final ResponseEnum responseEnum;

  ResponseModel({required this.data, required this.responseEnum});
}

enum ResponseEnum {
  success,
  fail,
  passwordUserIncorrect,
  duplicateUser,
  duplicateHN,
  patientNoFound,
}
