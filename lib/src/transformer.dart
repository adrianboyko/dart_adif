

import 'dart:async';
import 'dart:typed_data';

import 'package:charcode/charcode.dart';

import 'record.dart';

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

class AdifTransformer extends StreamTransformerBase<List<int>, AdifRecord> {

  const AdifTransformer();

  static Stream<AdifRecord> parse(Stream<List<int>> source) async* {
    var state = _ParserState.seekingTagStart;
    var tagNameBuf = ByteData(tagNameBufSize);
    var fieldValBuf = ByteData(fieldValBufSize);
    var fieldValLen = 0;
    var fieldTypeBuf = ByteData(fieldTypeBufSize);
    var tagNamePos = 0;
    var fieldValPos = 0;
    var fieldTypePos = 0;
    var wipRecord = AdifRecord();

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
              // Example: Copyright (C) 2012 Bob Smith <person@example.com>
              var tnb = tagNameBuf.getInt8;
              if (tnb(0) == $e && tnb(1) == $o && tnb(2) == $r) { // eor
                wipRecord.isHeader = false;
              }
              else if (tnb(0) == $e && tnb(1) == $o && tnb(2) == $h) { // eoh
                wipRecord.isHeader = true;
              }
              else {
                // This is where we handle the non-eoh, non-eor case, mentioned above.
                // We'll just ignore <...> and start looking for another tag.
                state = _ParserState.seekingTagStart;
                break;
              }
              yield wipRecord; // yield the record we've been constructing.
              wipRecord = AdifRecord(); // create a new record to populate.
              state = _ParserState.seekingTagStart;
            }
            else if (byte == $colon) {
              fieldValLen = 0; // We're going to begin collecting a new val len.
              state = _ParserState.collectingFieldValueLen;
            }
            else {
              if (tagNamePos < tagNameBufSize - 1) {
                if (byte >= $A && byte <= $Z) {
                  byte += 32; // This converts tag names to lower case.
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
              wipRecord.setValue(fName, fVal);
              state = _ParserState.seekingTagStart;
            }
            // end of cases
        }
      }
    }
  }

  @override
  Stream<AdifRecord> bind(Stream<List<int>> stream) {
    return parse(stream);
  }

}