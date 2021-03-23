
part of dart_adif;

enum _ParserState {
  seekingTagStart,
  collectingTagName,
  collectingFieldValueLen,
  collectingFieldType,
  collectingFieldValue,
}

/// The maximum length allowed for a tag/field name.
///
/// If this length is exceeded, the name will be truncated and an issue
/// will be logged in [AdifRecord.issues].
const tagNameBufSize = 50;

/// The maximum length allowed for a field type.
///
/// If this length is exceeded, the type will be truncated and an issue
/// will be logged in [AdifRecord.issues].
const fieldTypeBufSize = 50;

/// The maximum length of a field value.
///
/// If this length is exceeded, the value will be truncated and an issue
/// will be logged in [AdifRecord.issues].
const fieldValBufSize = 1024;

/// Transforms a stream of byte chunks into a stream of [AdifRecord]s.
///
/// If any issues are encountered during the transformation, they are noted
/// in [AdifRecord.issues] and the transformation continues.
///
/// See also `example/read_adif_file.dart`.ll
class AdifTransformer extends StreamTransformerBase<List<int>, AdifRecord> {
  const AdifTransformer();

  @override
  Stream<AdifRecord> bind(Stream<List<int>> stream) {
    return _parseAdif(stream);
  }
}

String _byteBufToStr(ByteData buf, int start, int end) {
  var char_codes = Uint8List.view(buf.buffer, start, end);
  return String.fromCharCodes(char_codes);
}

Stream<AdifRecord> _parseAdif(Stream<List<int>> source) async* {
  var state = _ParserState.seekingTagStart;
  var tagNameBuf = ByteData(tagNameBufSize);
  var fieldValBuf = ByteData(fieldValBufSize);
  var fieldValLen = 0;
  var fieldTypeBuf = ByteData(fieldTypeBufSize);
  var tagNamePos = 0;
  var fieldValPos = 0;
  var fieldTypePos = 0;
  var wipRecord = AdifRecord();
  var fieldNameTruncated = false;
  var fieldTypeTruncated = false;
  var fieldValTruncated = false;

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
            if (tagNamePos < tagNameBufSize) {
              if (byte >= $A && byte <= $Z) {
                byte += 32; // This converts tag names to lower case.
              }
              tagNameBuf.setInt8(tagNamePos, byte);
              tagNamePos += 1;
            }
            else {
              fieldNameTruncated = true; // We'll log this later.
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
            var fName = _byteBufToStr(tagNameBuf, 0, tagNamePos);
            var badChar = String.fromCharCode(byte);
            wipRecord._addIssue('Non-digit found in length spec: <$fName:$fieldValLen$badChar');
            // Might as well just give up and scan for the next field or eor.
            state = _ParserState.seekingTagStart;
          }
          break;

        case _ParserState.collectingFieldType:
          if (byte == $gt) {
            fieldValPos = 0;
            state = _ParserState.collectingFieldValue;
          }
          else {
            if (fieldTypePos < fieldTypeBufSize) {
              fieldTypeBuf.setInt8(fieldTypePos, byte);
              fieldTypePos += 1;
            }
            else {
              fieldTypeTruncated = true;
            }
            // state remains the same.
          }
          break;

        case _ParserState.collectingFieldValue:
          if (fieldValLen > 0) {
            fieldValLen -= 1;
            if (fieldValPos < fieldValBufSize) {
              fieldValBuf.setInt8(fieldValPos, byte);
              fieldValPos += 1;
            }
            else {
              fieldValTruncated = true;
            }
          }
          if (fieldValLen == 0) {
            var fName = _byteBufToStr(tagNameBuf, 0, tagNamePos);
            var fVal = _byteBufToStr(fieldValBuf, 0, fieldValPos);
            var fType = _byteBufToStr(fieldTypeBuf, 0, fieldTypePos);

            if (fieldNameTruncated) {
              wipRecord._addIssue('Field name was truncated to: $fName');
            }
            if (fieldValTruncated) {
              wipRecord._addIssue('Field value was truncated to: $fVal');
            }
            if (fieldTypeTruncated) {
              wipRecord._addIssue('Field type was truncated to: $fType');
            }

            // TODO: Decide what to do with fType.
            wipRecord.setFieldValue(fName, fVal);

            fieldNameTruncated = false;
            fieldValTruncated = false;
            fieldTypeTruncated = false;
            state = _ParserState.seekingTagStart;
          }
      // end of cases
      }
    }
  }
}
