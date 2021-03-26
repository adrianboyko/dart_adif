# dart_adif ![CI Status](https://github.com/adrianboyko/dart_adif/actions/workflows/ci.yml/badge.svg) ![](https://raw.githubusercontent.com/adrianboyko/dart_adif/main/coverage/coverage.svg)

A Dart library to read and write ADIF (Amateur Radio Data Interchange Format) files.

## Usage

A simple usage example:

```dart
import 'dart:io';
import 'package:dart_adif/dart_adif.dart';

void main() async {
  final adifStream = File('testdata/xlog.adi').openRead();
  final recordStream = adifStream.transform(AdifTransformer());
  await for (var record in recordStream) {
    print(record);
  }
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/adrianboyko/dart_adif/issues
