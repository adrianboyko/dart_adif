import 'dart:io';
import 'package:dart_adif/dart_adif.dart';

void main() async {
  final adifStream = File('testdata/xlog.adi').openRead();
  final recordStream = adifStream.transform(AdifTransformer());
  await for (var record in recordStream) {
    print(record);
  }
}
