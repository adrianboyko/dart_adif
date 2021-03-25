/// Tools for reading and writing ADIF, the amateur-radio data interchange format.
library dart_adif;

import 'dart:collection';
import 'dart:async';
import 'dart:typed_data';
import 'package:charcode/charcode.dart';

part 'src/fields.dart';
part 'src/record.dart';
part 'src/transformer.dart';
