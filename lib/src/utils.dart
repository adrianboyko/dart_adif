
import 'dart:typed_data';

class ByteDataWithPos {
  final ByteData _data;
  final int _dataSize;
  int _pos = 0;
  bool _truncated = false;
  
  ByteDataWithPos(this._dataSize) : _data = ByteData(_dataSize);
  
  void addInt8(int b) {
    if (_pos < _dataSize) {
      _data.setInt8(_pos++, b);
    } else {
      _truncated = true;
    }
  }

  int getInt8(int pos) {
    return _data.getInt8(pos);
  }

  void reset() {
    _pos = 0;
    _truncated = false;
  }
  
  bool get truncated { 
    return _truncated; 
  }

  String get dataAsStr {
    var char_codes = Uint8List.view(_data.buffer, 0, _pos);
    return String.fromCharCodes(char_codes);
  }

}