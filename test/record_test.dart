
import 'dart:io';
import 'dart:typed_data';

import 'package:adif/src/record.dart';
import 'package:test/test.dart';

void main() {
  test('Basic Record Test', () async {
    var chunk = '<blah:2>AB<FOO:3>XYZ<bar:4:s>1234<eor>';
    var expectedFields = {
      'blah': 'AB',
      'FOO': 'XYZ',
      'bar': '1234',
    };
    var input = Uint8List.fromList(chunk.codeUnits);
    var output = Record.parse(Stream.value(input));
    await for (var record in output) {
      for (MapEntry e in expectedFields.entries) {
        var actual = record.getFieldValue(e.key);
        var expected = e.value;
        expect(actual, equals(expected));
      }
    }
  });

  test('Test comment after record', () async {
    var chunk = '<blah:2>AB<FOO:3>XYZ<bar:4:s>1234<eor>  // Comment';
    var expectedFields = {
      'blah': 'AB',
      'FOO': 'XYZ',
      'bar': '1234',
    };
    var input = Uint8List.fromList(chunk.codeUnits);
    var output = Record.parse(Stream.value(input));
    await for (var record in output) {
      for (MapEntry e in expectedFields.entries) {
        var actual = record.getFieldValue(e.key);
        var expected = e.value;
        expect(actual, equals(expected));
      }
    }
  });

  test('Test whitespace', () async {
    var chunk = '  <call:4>W1AW  <STATION_CALL:6>KF4MDV  <eor>  ';
    var expectedFields = {
      'call': 'W1AW',
      'STATION_CALL': 'KF4MDV',
    };
    var input = Uint8List.fromList(chunk.codeUnits);
    var output = Record.parse(Stream.value(input));
    await for (var record in output) {
      for (MapEntry e in expectedFields.entries) {
        var actual = record.getFieldValue(e.key);
        var expected = e.value;
        expect(actual, equals(expected));
      }
    }
  });

  test('Test parsing across chunks', () async {
    var chunks = [
      Uint8List.fromList('<blah:02>AB <FOO:3>XYZ <bar:'.codeUnits),
      Uint8List.fromList('4:s>1234 <eor>'.codeUnits),
    ];
    var expectations = {
      'blah': 'AB',
      'FOO': 'XYZ',
      'bar': '1234',
    };
    var output = Record.parse(Stream.fromIterable(chunks));
    await for (var record in output) {
      for (MapEntry e in expectations.entries) {
        var actual = record.getFieldValue(e.key);
        var expected = e.value;
        expect(actual, equals(expected));
      }
    }
  });

  test('Test LoTW ADIF', () async {

    var input = File('testdata/lotw.adi').openRead();
    var output = Record.parse(input);
    Record? header;
    await for (var record in output) {
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

    var input = File('testdata/xlog.adi').openRead();
    var output = Record.parse(input);
    Record? header;
    await for (var record in output) {
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



