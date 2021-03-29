part of dart_adif;

enum _State {
  seekingTagStart,
  collectingName,
  collectingValLen,
  collectingType,
  collectingVal,
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
class AdifTransformer extends StreamTransformerBase<List<int>, AdifRecord> {
  const AdifTransformer();

  @override
  Stream<AdifRecord> bind(Stream<List<int>> stream) {
    return _AdifParser().parse(stream);
  }
}

class _AdifParser {
  final nameBuf = ByteDataWithPos(tagNameBufSize);
  final valBuf = ByteDataWithPos(fieldValBufSize);
  final typeBuf = ByteDataWithPos(fieldTypeBufSize);
  var valLen = 0;
  var wipRec = AdifRecord();

  void storeByte(final _State state, final int byte) {
    switch (state) {
      case _State.seekingTagStart:
        break; // This state doesn't store anything.

      case _State.collectingName:
        var lcByte = (byte >= $A && byte <= $Z) ? byte | 32 : byte;
        nameBuf.addInt8(lcByte);
        break;

      case _State.collectingValLen:
        valLen *= 10; // TODO: guard against overflow.
        valLen += byte - $0; // TODO: guard against overflow.
        break;

      case _State.collectingType:
        typeBuf.addInt8(byte);
        break;

      case _State.collectingVal:
        assert(valLen >= 0);
        valBuf.addInt8(byte);
    }
  }

  _State getNextState(final _State currState, final int byte) {
    switch (currState) {
      case _State.seekingTagStart:
        switch (byte) {
          case $lt:
            return _State.collectingName;
          default:
            return currState;
        }

      case _State.collectingName:
        switch (byte) {
          case $gt:
            // We've presumably collected eo[hr], so look for the next tag.
            return _State.seekingTagStart;
          case $colon:
            return _State.collectingValLen;
          default:
            return currState;
        }

      case _State.collectingValLen:
        switch (byte) {
          case $colon:
            return _State.collectingType;
          case $gt:
            return _State.collectingVal;
          case $0:
          case $1:
          case $2:
          case $3:
          case $4:
          case $5:
          case $6:
          case $7:
          case $8:
          case $9:
            return currState;
          default:
            // We've encountered a non-numeric char in a field value length.
            var badChar = String.fromCharCode(byte);
            var badTag = '<...:$valLen$badChar...>';
            wipRec._addIssue('Non-digit found in length spec: $badTag');
            // Might as well just give up and scan for the next field or eo[rh].
            return _State.seekingTagStart;
        }

      case _State.collectingType:
        switch (byte) {
          case $gt:
            return _State.collectingVal;
          default:
            return currState;
        }

      case _State.collectingVal:
        if (--valLen == 0) {
          // Because this transition is triggered by a countdown instead of by
          // an input byte that indicates the transition, we need to perform
          // a nonstandard _storeByte here so that the current byte isn't lost.
          storeByte(currState, byte);
          return _State.seekingTagStart;
        } else {
          return currState;
        }
    }
  }

  AdifRecord? reactToTransition(final _State oldState, final _State newState) {
    switch (oldState) {
      case _State.seekingTagStart:
        // No action required when leaving this state.
        break;

      case _State.collectingName:
        if (newState == _State.seekingTagStart) {
          // We have encountered a tag with no value, probably eor or eoh.
          var tnb = nameBuf.getInt8;
          var isEndOfTag = tnb(0) == $e && tnb(1) == $o;
          var isEorTag = isEndOfTag && tnb(2) == $r;
          var isEohTag = isEndOfTag && tnb(2) == $h;
          if (isEorTag || isEohTag) {
            wipRec.isHeader = isEohTag;
            var completedRecord = wipRec;
            wipRec = AdifRecord(); // create a new record to populate.
            return completedRecord;
          } else {
            var fName = nameBuf.dataAsStr;
            wipRec._addIssue('Expected <eoh> or <eor> but found <$fName>');
          }
        }
        break;

      case _State.collectingValLen:
        // No action required when leaving this state.
        break;

      case _State.collectingType:
        // No action required when leaving this state.
        break;

      case _State.collectingVal:
        var fName = nameBuf.dataAsStr;
        var fVal = valBuf.dataAsStr;
        var fType = typeBuf.dataAsStr;
        if (nameBuf.truncated) {
          wipRec._addIssue('Field name was truncated to: $fName');
        }
        if (valBuf.truncated) {
          wipRec._addIssue('Field value was truncated to: $fVal');
        }
        if (typeBuf.truncated) {
          wipRec._addIssue('Field type was truncated to: $fType');
        }
        // TODO: Decide what to do with fType.
        wipRec.setFieldValue(fName, fVal);
        // We deviate from true FSM here by forcing the next state:
        break;
    }

    switch (newState) {
      case _State.seekingTagStart:
        // No action required when entering this state.
        break;

      case _State.collectingName:
        nameBuf.reset();
        break;

      case _State.collectingValLen:
        valLen = 0;
        break;

      case _State.collectingType:
        typeBuf.reset();
        break;

      case _State.collectingVal:
        valBuf.reset();
        break;
    }
  }

  Stream<AdifRecord> parse(Stream<List<int>> source) async* {
    var state = _State.seekingTagStart;
    await for (var bytes in source) {
      for (var byte in bytes) {
        var nextState = getNextState(state, byte);

        // Either the byte drove a state change that we should react to
        // or the byte is data that needs to be saved.
        if (state != nextState) {
          var maybeRecord = reactToTransition(state, nextState);
          if (maybeRecord != null) yield maybeRecord;
        } else {
          storeByte(state, byte);
        }

        state = nextState;
      }
    }
  }
}
