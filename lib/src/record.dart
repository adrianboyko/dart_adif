
import 'dart:collection';

import 'fields.dart';


class AdifRecord {

  final _values = <String, String>{};
  List<String>? _issues;
  bool isHeader = false; // Assume the usual case, until proven otherwise.

  String? getFieldValue(String fieldName) {
    return _values[fieldName.toLowerCase()];
  }

  String? operator [](String fieldName) {
    return getFieldValue(fieldName);
  }
  
  void setValue(String fieldName, String fieldValue) {
    _values[fieldName] = fieldValue;
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

    // Append end-of-record/header tag
    result.write(isHeader ? '<eoh>' : '<eor>');

    return result.toString();
  }

  void addIssue(String description) {
    _issues == null ? _issues = [description] : _issues!.add(description);
  }

  UnmodifiableListView<String>? get issues {
    return _issues == null ? null : UnmodifiableListView(_issues!);
  }

}

