import 'dart:io';

import 'package:adif/src/record.dart';

void main() async {
  final input = File('testdata/xlog.adi').openRead();
  final output = Record.parse(input);
  await for (var record in output) {
    print(record);
  }
}
