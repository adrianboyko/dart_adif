
part of dart_adif;

/// Represents a single ADIF record and its fields.
class AdifRecord {

  final _values = <String, String>{};

  List<String>? _issues;

  /// Indicates whether the record represents the ADIF header or ADIF data.
  ///
  /// An ADIF file may contain one header record in addition to any number of
  /// data records. This property is `true` for a header and `false` for data.
  bool isHeader = false; // Assume the usual case, until proven otherwise.

  /// Returns the value of the named field, or `null` if no such field.
  ///
  /// This method is case-insensitive with respect to the field name.
  String? getFieldValue(String fieldName) {
    return _values[fieldName.toLowerCase()];
  }

  /// Returns the value of the field whose name is the index.
  ///
  /// This method is case-insensitive with respect to the field name.
  String? operator [](String fieldName) {
    return getFieldValue(fieldName);
  }

  /// Sets the value of the named field to the given value.
  ///
  /// The case of the provided field name does not matter and it will be
  /// converted to lower case, internally.
  void setFieldValue(String fieldName, String fieldValue, [adifType fieldType = adifType.ADIFString]) {
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

  /// Returns the record as a string in the ADIF format.
  ///
  /// The returned string can be written to an ADIF file.
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

  void _addIssue(String description) {
    _issues == null ? _issues = [description] : _issues!.add(description);
  }

  /// Issues that were encountered during the creation of this record.
  ///
  /// When parsing a file into a stream of records, it is possible that there
  /// will be problems. If so, this property is a list of strings describing
  /// the problems. If not, then this property will be `null`.
  UnmodifiableListView<String>? get issues {
    return _issues == null ? null : UnmodifiableListView(_issues!);
  }

}

