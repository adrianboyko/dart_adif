
import 'dart:typed_data';

import 'package:charcode/charcode.dart';
import 'fields.dart';

enum _ParserState {
  seekingTagStart,
  collectingTagName,
  collectingFieldValueLen,
  collectingFieldType,
  collectingFieldValue,
}

const tagNameBufSize = 50;
const fieldTypeBufSize = 50;
const fieldValBufSize = 1024;

class Record {
  final _values = <String, String>{};
  late final bool? isHeader;

  String? getFieldValue(String fieldName) {
    return _values[fieldName.toLowerCase()];
  }

  String? operator [](String fieldName) {
    return getFieldValue(fieldName);
  }
  
  void _setValue(String fieldName, String fieldValue) {
    _values[fieldName] = fieldValue;
  }

  static Stream<Record> parse(Stream<List<int>> source) async* {
    var state = _ParserState.seekingTagStart;
    var tagNameBuf = ByteData(tagNameBufSize);
    var fieldValBuf = ByteData(fieldValBufSize);
    var fieldValLen = 0;
    var fieldTypeBuf = ByteData(fieldTypeBufSize);
    var tagNamePos = 0;
    var fieldValPos = 0;
    var fieldTypePos = 0;
    var currRecord = Record();

    await for (var bytes in source) {
      for (var byte in bytes) {
        switch (state) {

          case _ParserState.seekingTagStart:
            if (byte == $lt) {
              tagNamePos = 0; // We're going to begin collecting a new tag name.
              state = _ParserState.collectingTagName;
            }
            else {
              // No action and state remains the same.
            }
            break;

          case _ParserState.collectingTagName:
            if (byte == $gt) {
              // Ideally, this would only happen when we encounter <eoh> pr <eor>.
              // However, it also happens when email addresses are encountered in the header.
              // Example: Copyright (C) 2012 Fname Lname <person@example.com>
              var tnb = tagNameBuf.getInt8;
              if (tnb(0)==$e && tnb(1)==$o && tnb(2)==$r) {  // eor
                currRecord.isHeader = false;
              }
              else if (tnb(0)==$e && tnb(1)==$o && tnb(2)==$h) {  // eoh
                currRecord.isHeader = true;
              }
              else {
                // This is where we handle the non-eoh, non-eor case.
                // We'll just ignore <...> and start looking for another tag.
                state = _ParserState.seekingTagStart;
                break;
              }
              yield currRecord; // yield the record we've been constructing.
              currRecord = Record(); // create a new record to populate.
              state = _ParserState.seekingTagStart;
            }
            else if (byte == $colon) {
              fieldValLen = 0; // We're going to begin collecting a new val len.
              state = _ParserState.collectingFieldValueLen;
            }
            else {
              if (tagNamePos < tagNameBufSize - 1) {
                if (byte >= $A && byte <= $Z) {
                  byte += 32; // This converts tagnames to lower case.
                }
                tagNameBuf.setInt8(tagNamePos, byte);
                tagNamePos += 1;
              }
              else {
                // TODO: Log a filed name truncation warning.
              }
            }
            break;

          case _ParserState.collectingFieldValueLen:
            if (byte == $colon) {
              fieldTypePos = 0;
              state = _ParserState.collectingFieldType;
            }
            else if (byte == $gt) {
              fieldValPos = 0;
              state = _ParserState.collectingFieldValue;
            }
            else if ((byte >= $0) && (byte <= $9)) {
              // Note, no real need to guard against overflow.
              fieldValLen *= 10;
              fieldValLen += byte - $0;
              // state remains the same.
            }
            else {
              // We've encountered a non-numeric char in field value length.
              // Might as well just give up and scan for the next field or eor.
              // TODO: Log bad field length warning.
              state = _ParserState.seekingTagStart;
            }
            break;

          case _ParserState.collectingFieldType:
            if (byte == $gt) {
              fieldValPos = 0;
              state = _ParserState.collectingFieldValue;
            }
            else {
              if (fieldTypePos < fieldTypeBufSize - 1) {
                fieldTypeBuf.setInt8(fieldTypePos, byte);
                fieldTypePos += 1;
              }
              else {
                // TODO: Log a field type truncation warning.
              }
              // state remains the same.
            }
            break;

          case _ParserState.collectingFieldValue:
            if (fieldValLen > 0) {
              fieldValLen -= 1;
              if (fieldValPos < fieldValBufSize - 1) {
                fieldValBuf.setInt8(fieldValPos, byte);
                fieldValPos += 1;
              }
              else {
                // TODO: Log a field value truncation warning.
              }
              // state remains the same.
            }
            if (fieldValLen == 0) {
              var fNameCCs = Uint8List.view(tagNameBuf.buffer, 0, tagNamePos);
              var fValCCs = Uint8List.view(fieldValBuf.buffer, 0, fieldValPos);
              var fName = String.fromCharCodes(fNameCCs);
              var fVal = String.fromCharCodes(fValCCs);
              currRecord._setValue(fName, fVal);
              state = _ParserState.seekingTagStart;
            }
          // end of cases
        }
      }
    }
  }

  // Append a field to a string buffer.
  static void _appendField(StringBuffer sb, String fName, String fValue) {
    sb
      ..write('<')
      ..write(fName)
      ..write(':')
      ..write(fValue.length.toString())
      ..write('>')
      ..write(fValue);
  }

  // Print as ADIF String
  @override
  String toString() {

    var result = StringBuffer();

    // Append standard fields in order defined by adifFieldInfo map
    adifFieldInfo.forEach((fName, _) {
      var fVal = _values[fName];
      if (fVal != null) _appendField(result, fName, fVal);
    });

    // Append custom fields in no particular order
    _values.forEach((fName, fVal) {
      var isCustomField = !adifStandardFieldNames.contains(fName);
      if (isCustomField) _appendField(result, fName, fVal);
    });

    return result.toString();
  }

}

