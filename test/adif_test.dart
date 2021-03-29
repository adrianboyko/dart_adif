
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:dart_adif/dart_adif.dart';

void main() {

  group('Basic Parsing', () {

    test('Basic record test', () async {
      final chunk = '<blah:2>AB<FOO:3>XYZ<bar:4:s>1234<eor>';
      final expectedFields = {
        'blah': 'AB',
        'FOO': 'XYZ',
        'bar': '1234',
      };
      final input = Stream.value(Uint8List.fromList(chunk.codeUnits));
      final output = AdifTransformer().bind(input);
      var recCount = 0;
      await for (final record in output) {
        recCount += 1;
        expect(record.issues, isNull);
        for (MapEntry e in expectedFields.entries) {
          final actual = record[e.key];
          final expected = e.value;
          expect(actual, equals(expected));
        }
      }
      expect(recCount, equals(1));
    });

    test('Test comment after record', () async {
      final chunk = '<blah:2>AB<FOO:3>XYZ<bar:4:s>1234<eor>  // Comment';
      final expectedFields = {
        'blah': 'AB',
        'FOO': 'XYZ',
        'bar': '1234',
      };
      final input = Stream.value(Uint8List.fromList(chunk.codeUnits));
      final output = AdifTransformer().bind(input);
      var recCount = 0;
      await for (final record in output) {
        recCount += 1;
        expect(record.issues, isNull);
        for (MapEntry e in expectedFields.entries) {
          final actual = record[e.key];
          final expected = e.value;
          expect(actual, equals(expected));
        }
      }
      expect(recCount, equals(1));
    });

    test('Test whitespace', () async {
      final chunk = '  <call:4>W1AW  <STATION_CALL:6>KF4MDV  <eor>  ';
      final expectedFields = {
        'call': 'W1AW',
        'STATION_CALL': 'KF4MDV',
      };
      final input = Stream.value(Uint8List.fromList(chunk.codeUnits));
      final output = AdifTransformer().bind(input);
      var recCount = 0;
      await for (final record in output) {
        recCount += 1;
        expect(record.issues, isNull);
        for (MapEntry e in expectedFields.entries) {
          final actual = record[e.key];
          final expected = e.value;
          expect(actual, equals(expected));
        }
      }
      expect(recCount, equals(1));
    });
  });

  group('Writing', () {
    test('ToString', () async {
      final inStr = '  <call:4>W1AW  <STATION_CALL:6>KF4MDV  <eor>  // comment';
      final input = Stream.value(Uint8List.fromList(inStr.codeUnits));
      final output = AdifTransformer().bind(input);
      final expected = '<call:4>W1AW<station_call:6>KF4MDV<eor>';
      var recCount = 0;
      await for (final record in output) {
        recCount += 1;
        expect(record.issues, isNull);
        expect(record.toString(), equals(expected));
      }
      expect(recCount, equals(1));
    });
  });

  group('Stream Transformer', () {

    test('Test parsing across chunks', () async {
      final chunks = [
        Uint8List.fromList('<blah:02>AB <FOO:3>XYZ <bar:'.codeUnits),
        Uint8List.fromList('4:s>1234 <eor>'.codeUnits),
      ];
      final expectations = {
        'blah': 'AB',
        'FOO': 'XYZ',
        'bar': '1234',
      };
      final input = Stream.fromIterable(chunks);
      final output = AdifTransformer().bind(input);
      var recCount = 0;
      await for (final record in output) {
        recCount += 1;
        expect(record.issues, isNull);
        for (MapEntry e in expectations.entries) {
          final actual = record[e.key];
          final expected = e.value;
          expect(actual, equals(expected));
        }
      }
      expect(recCount, equals(1));
    });

    test('Test as argument to transform() method', () async {
      final adifStream = File('testdata/xlog.adi').openRead();
      final recordStream = adifStream.transform(AdifTransformer());
      AdifRecord? header;
      await for (final record in recordStream) {
        if (record.isHeader == true) {
          header = record;
        }
        else {
          expect(record['call'], isNotNull);
          expect(record['freq'], isNotNull);
        }
      }
      expect(header, isNotNull);
      expect(header!['ADIF_VER'], equals('2.2.7'));
    });
  });

  group('Truncation and logging', () {

    test('Test field name truncation and logging', () async {
      final truncatedFieldName = 'x' * tagNameBufSize;
      final longFieldName = truncatedFieldName + 'y';
      final chunk = '<blah:2>AB<$longFieldName:3>XYZ<bar:4:s>1234<eor>';
      final expectedFields = {
        'blah': 'AB',
        '$truncatedFieldName': 'XYZ',
        'bar': '1234',
      };
      final input = Stream.value(Uint8List.fromList(chunk.codeUnits));
      final output = AdifTransformer().bind(input);
      await for (final record in output) {
        expect(record.issues!.length, equals(1));
        expect(record.issues!.first, contains(truncatedFieldName));
        for (MapEntry e in expectedFields.entries) {
          final actual = record[e.key];
          final expected = e.value;
          expect(actual, equals(expected));
        }
      }
    });

    test('Test field value truncation and logging', () async {
      final truncatedFieldVal = 'x' * fieldValBufSize;
      final longFieldVal = truncatedFieldVal + 'y';
      final chunk = '<blah:2>AB<FOO:${longFieldVal.length}>$longFieldVal<bar:4:s>1234<eor>';
      final expectedFields = {
        'blah': 'AB',
        'foo': '$truncatedFieldVal',
        'bar': '1234',
      };
      final input = Stream.value(Uint8List.fromList(chunk.codeUnits));
      final output = AdifTransformer().bind(input);
      await for (final record in output) {
        expect(record.issues!.length, equals(1));
        expect(record.issues!.first, contains(truncatedFieldVal));
        for (MapEntry e in expectedFields.entries) {
          final actual = record[e.key];
          final expected = e.value;
          expect(actual, equals(expected));
        }
      }
    });

    test('Test field type truncation and logging', () async {
      final truncatedFieldType = 'x' * fieldTypeBufSize;
      final longFieldType = truncatedFieldType + 'y';
      final chunk = '<blah:2>AB<FOO:4:$longFieldType>Test<bar:4:s>1234<eor>';
      final expectedFields = {
        'blah': 'AB',
        'foo': 'Test',
        'bar': '1234',
      };
      final input = Stream.value(Uint8List.fromList(chunk.codeUnits));
      final output = AdifTransformer().bind(input);
      await for (final record in output) {
        expect(record.issues!.length, equals(1));
        expect(record.issues!.first, contains(truncatedFieldType));
        for (MapEntry e in expectedFields.entries) {
          final actual = record[e.key];
          final expected = e.value;
          expect(actual, equals(expected));
        }
      }
    });

    test('Test bad field length handling and logging', () async {
      final chunk = '<blah:2>AB<FOO:4a>XYZ<bar:4:s>1234<eor>';
      final expectedFields = {
        'blah': 'AB',
        'bar': '1234',
      };
      final input = Stream.value(Uint8List.fromList(chunk.codeUnits));
      final output = AdifTransformer().bind(input);
      await for (final record in output) {
        expect(record.issues!.length, equals(1));
        expect(record.issues!.first, contains('4a'));
        for (MapEntry e in expectedFields.entries) {
          final actual = record[e.key];
          final expected = e.value;
          expect(actual, equals(expected));
        }
      }
    });
  });

  group('Real world test data', () {

    test('Test LoTW ADIF', () async {
      final input = File('testdata/lotw.adi').openRead();
      final output = AdifTransformer().bind(input);
      AdifRecord? header;
      await for (final record in output) {
        if (record.isHeader == true) {
          header = record;
        }
        else {
          expect(record['call'], isNotNull);
          expect(record['freq'], isNotNull);
        }
      }
      expect(header, isNotNull);
      expect(header!['programid'], equals('LoTW'));
    });

    test('Test Xlog ADIF', () async {
      final input = File('testdata/xlog.adi').openRead();
      final output = AdifTransformer().bind(input);
      AdifRecord? header;
      await for (final record in output) {
        if (record.isHeader == true) {
          header = record;
        }
        else {
          expect(record['call'], isNotNull);
          expect(record['freq'], isNotNull);
        }
      }
      expect(header, isNotNull);
      expect(header!.issues!.length, equals(2));
      expect(header.issues, contains('Expected <eoh> or <eor> but found <andystewart@comcast.net>'));
      expect(header.issues, contains('Expected <eoh> or <eor> but found <pg4i@amsat.org>'));
      expect(header['ADIF_VER'], equals('2.2.7'));
    });

  });

}



