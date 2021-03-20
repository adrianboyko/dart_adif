import 'dart:io';

import 'package:adif/src/transformer.dart';

void main() async {
  final adifFile = File('testdata/xlog.adi');
  final recordStream = adifFile.openRead().transform(AdifTransformer());
  await for (var record in recordStream) {
    print(record);
  }
}
