
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:adif/adif.dart';


void main() {
  test('Basic Record Test', () async {
    final chunk = '<blah:2>AB<FOO:3>XYZ<bar:4:s>1234<eor>';
    final expectedFields = {
      'blah': 'AB',
      'FOO': 'XYZ',
      'bar': '1234',
    };
    final input = Uint8List.fromList(chunk.codeUnits);
    final output = parseAdif(Stream.value(input));
    await for (final record in output) {
      for (MapEntry e in expectedFields.entries) {
        final actual = record.getFieldValue(e.key);
        final expected = e.value;
        expect(actual, equals(expected));
      }
    }
  });

  test('Test comment after record', () async {
    final chunk = '<blah:2>AB<FOO:3>XYZ<bar:4:s>1234<eor>  // Comment';
    final expectedFields = {
      'blah': 'AB',
      'FOO': 'XYZ',
      'bar': '1234',
    };
    final input = Uint8List.fromList(chunk.codeUnits);
    final output = parseAdif(Stream.value(input));
    await for (final record in output) {
      for (MapEntry e in expectedFields.entries) {
        final actual = record.getFieldValue(e.key);
        final expected = e.value;
        expect(actual, equals(expected));
      }
    }
  });

  test('Test whitespace', () async {
    final chunk = '  <call:4>W1AW  <STATION_CALL:6>KF4MDV  <eor>  ';
    final expectedFields = {
      'call': 'W1AW',
      'STATION_CALL': 'KF4MDV',
    };
    final input = Uint8List.fromList(chunk.codeUnits);
    final output = parseAdif(Stream.value(input));
    await for (final record in output) {
      for (MapEntry e in expectedFields.entries) {
        final actual = record.getFieldValue(e.key);
        final expected = e.value;
        expect(actual, equals(expected));
      }
    }
  });

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
    final output = parseAdif(Stream.fromIterable(chunks));
    await for (final record in output) {
      for (MapEntry e in expectations.entries) {
        final actual = record.getFieldValue(e.key);
        final expected = e.value;
        expect(actual, equals(expected));
      }
    }
  });

  test('Test LoTW ADIF', () async {
    final input = File('testdata/lotw.adi').openRead();
    final output = parseAdif(input);
    AdifRecord? header;
    await for (final record in output) {
      if (record.isHeader == true) {
        header = record;
      }
      else {
        expect(record['call'], isNotNull);
        expect(record['freq'], isNotNull);
      }
      //print(record);
    }
    expect(header, isNotNull);
    expect(header!['programid'], equals('LoTW'));
  });

  test('Test Xlog ADIF', () async {
    final input = File('testdata/xlog.adi').openRead();
    final output = parseAdif(input);
    AdifRecord? header;
    await for (final record in output) {
      if (record.isHeader == true) {
        header = record;
      }
      else {
        expect(record['call'], isNotNull);
        expect(record['freq'], isNotNull);
      }
      //print(record);
    }
    expect(header, isNotNull);
    expect(header!['ADIF_VER'], equals('2.2.7'));
  });

  test('Test AdifTransformer', () async {
    final adifFile = File('testdata/xlog.adi');
    final recordStream = adifFile.openRead().transform(AdifTransformer());
    AdifRecord? header;
    await for (final record in recordStream) {
      if (record.isHeader == true) {
        header = record;
      }
      else {
        expect(record['call'], isNotNull);
        expect(record['freq'], isNotNull);
      }
      //print(record);
    }
    expect(header, isNotNull);
    expect(header!['ADIF_VER'], equals('2.2.7'));
  });

}



