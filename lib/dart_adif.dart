/// Tools for reading and writing ADIF, the amateur-radio data interchange format.
library dart_adif;

import 'dart:collection';
import 'dart:async';
import 'package:charcode/charcode.dart';
import 'src/utils.dart';

part 'src/fields.dart';
part 'src/record.dart';
part 'src/transformer.dart';
