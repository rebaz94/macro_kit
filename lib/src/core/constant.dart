import 'package:macro_kit/src/core/core.dart';

List<Object>? _asListMPEncode(Object? value) {
  var toSet = false;
  if (value is! List) {
    if (value is! Set) {
      return null;
    }

    toSet = true;
    value = value.toList();
  }

  final result = <Object>[
    if (toSet) '__type::set__',
  ];

  for (final elem in value) {
    if (elem is! MacroProperty) {
      if (elem == '__type::set__' && !toSet) {
        result.add(elem);
        continue;
      }

      return null;
    }

    result.add(elem.toJson());
  }

  return result;
}

/// return `List<MacroProperty>` or `Set<MacroProperty>`
Object _asListMPDecode(List value) {
  bool toSet = false;
  final result = <MacroProperty>[];
  for (final elem in value) {
    if (elem is! Map) {
      if (elem == '__type::set__') {
        toSet = true;
      }

      continue;
    }

    result.add(MacroProperty.fromJson(elem as Map<String, dynamic>));
  }

  return toSet ? result.toSet() : result;
}

List<List<Object>>? _asListOfListMPEncode(Object? value) {
  if (value is! List) return null;

  final result = <List<Object>>[];
  var toSet = false;

  for (var elem in value) {
    if (elem is! List) {
      if (elem is! Set) {
        return null;
      }

      toSet = true;
      elem = elem.toList();
    }

    final innerList = <Object>[if (toSet) '__type::set__'];
    for (final v in elem) {
      if (v is! MacroProperty) {
        if (v == '__type::set__' && !toSet) {
          innerList.add(v);
          continue;
        }
        return null;
      }

      innerList.add(v.toJson());
    }

    result.add(innerList);
  }

  return result;
}

/// return `List<List<MacroProperty>>` or `List<Set<MacroProperty>>`
Object _asListOfListMPDecode(List value) {
  final result = <Object>[];
  for (final elem in value) {
    if (elem is! List) {
      print('_asListOfListMPDecode: ignored: $elem ');
      continue;
    }

    bool toSet = false;
    final innerList = <Object>[];
    for (final v in elem) {
      if (v is! Map) {
        if (v == '__type::set__') {
          toSet = true;
        }

        continue;
      }

      innerList.add(MacroProperty.fromJson(v as Map<String, dynamic>));
    }

    result.add(toSet ? innerList.toSet() : innerList);
  }

  return result;
}

Map<String, Map<String, dynamic>>? _asMapMPEncode(Object? value) {
  if (value is! Map) return null;
  if (value is Map<String, MacroProperty>) {
    return value.map((k, v) => MapEntry(k, v.toJson()));
  }

  final result = <String, Map<String, dynamic>>{};
  for (final elem in value.entries) {
    if (elem.key is! String || elem.value is! MacroProperty) {
      return null;
    }

    result[elem.key] = (elem.value as MacroProperty).toJson();
  }

  return result;
}

/// return `Map<String, MacroProperty>>`
Map<String, MacroProperty>? _asMapMPDecode(Map value) {
  final result = <String, MacroProperty>{};
  for (final elem in value.entries) {
    if (elem.key is! String || elem.value is! Map) {
      continue;
    }

    result[elem.key] = MacroProperty.fromJson(elem.value as Map<String, dynamic>);
  }

  return result;
}

Map<String, List<Object>>? _asMapOfListMPEncode(Object? value) {
  if (value is! Map) return null;

  final result = <String, List<Object>>{};
  var toSet = false;

  for (final elem in value.entries) {
    var elemVal = elem.value;
    if (elem.key is! String) return null;
    if (elemVal is! List) {
      if (elemVal is! Set) {
        return null;
      }

      toSet = true;
      elemVal = elemVal.toList();
    }

    final list = <Object>[];
    for (final v in elemVal) {
      if (v is! MacroProperty) {
        if (v == '__type::set__' && !toSet) {
          list.add(v);
          continue;
        }
        return null;
      }

      list.add(v.toJson());
    }

    result[elem.key] = list;
  }

  return result;
}

/// return `Map<String, List<MacroProperty>>` or `Map<String, Set<MacroProperty>>`
Map<String, Object>? _asMapOfListMPDecode(Map value) {
  final result = <String, /*List<MacroProperty>|Set<MacroProperty>*/ Object>{};
  for (final elem in value.entries) {
    if (elem.key is! String || elem.value is! List) {
      continue;
    }

    bool toSet = false;
    final list = <Object>[];
    for (final v in elem.value) {
      if (v is! Map) {
        if (v == '__type::set__') {
          toSet = true;
        }
        continue;
      }

      list.add(MacroProperty.fromJson(v as Map<String, dynamic>));
    }

    result[elem.key] = toSet ? list.toSet() : list;
  }

  return result;
}

Map<String, List<List<Object>>>? _asMapOfListOfListMPEncode(Object? value) {
  if (value is! Map) return null;

  final result = <String, List<List<Object>>>{};
  for (final elem in value.entries) {
    if (elem.key is! String || elem.value is! List) return null;

    final innerList = <List<Object>>[];
    var toSet = false;
    for (var v in elem.value) {
      if (v is! List) {
        if (v is! Set) {
          return null;
        }

        toSet = true;
        v = v.toList();
      }

      final innerList2 = <Object>[
        if (toSet) '__type::set__',
      ];
      for (final v2 in v) {
        if (v2 is! MacroProperty) {
          if (v2 == '__type::set__' && !toSet) {
            innerList2.add(v2);
            continue;
          }

          return null;
        }

        innerList2.add(v2.toJson());
      }

      innerList.add(innerList2);
    }

    result[elem.key] = innerList;
  }

  return result;
}

/// return `Map<String, List<List<MacroProperty>>` or `Map<String, List<Set<MacroProperty>>` or
Map<String, List<Object>>? _asMapOfListOfListMPDecode(Map value) {
  final result = <String, List<Object>>{};
  for (final elem in value.entries) {
    if (elem.key is! String || elem.value is! List) {
      continue;
    }

    final innerList = <Object>[];
    for (final v in elem.value) {
      if (v is! List) {
        continue;
      }

      bool toSet = false;
      final innerList2 = <Object>[];
      for (final v2 in v) {
        if (v2 is! Map) {
          if (v2 == '__type::set__') {
            toSet = true;
          }
          continue;
        }

        innerList2.add(MacroProperty.fromJson(v2 as Map<String, dynamic>));
      }

      innerList.add(toSet ? innerList2.toSet() : innerList2);
    }

    result[elem.key] = innerList;
  }

  return result;
}

(String typeId, Object? value) encodeConstantPropertyType(TypeInfo typeInfo, Object? constantValue) {
  if (constantValue == null) return ('', null);

  if (constantValue is MacroProperty) {
    return ('macro_property', constantValue.toJson());
  } else if (constantValue is Set) {
    return ('set', constantValue.toList());
  } else if (_asListMPEncode(constantValue) case final listVal?) {
    return ('list::macro_property', listVal);
  } else if (_asListOfListMPEncode(constantValue) case final listVal?) {
    return ('list::list::macro_property', listVal);
  } else if (_asMapMPEncode(constantValue) case final mapVal?) {
    return ('map::string-macro_property', mapVal);
  } else if (_asMapOfListMPEncode(constantValue) case final mapVal?) {
    return ('map::string-list::macro_property', mapVal);
  } else if (_asMapOfListOfListMPEncode(constantValue) case final mapVal?) {
    return ('map::string-list::list::macro_property', mapVal);
  } else {
    return ('', constantValue);
  }
}

Object? decodeConstantPropertyType(String typeId, Object? constantValue) {
  if (constantValue == null) return null;

  if (typeId == 'macro_property' && constantValue is Map) {
    return MacroProperty.fromJson(constantValue as Map<String, dynamic>);
  } else if (typeId == 'set' && constantValue is List) {
    if (constantValue.firstOrNull == '__type::set__') {
      constantValue.remove('__type::set__');
    }
    return constantValue.toSet();
  } else if (typeId == 'list::macro_property' && constantValue is List) {
    return _asListMPDecode(constantValue);
  } else if (typeId == 'list::list::macro_property' && constantValue is List) {
    return _asListOfListMPDecode(constantValue);
  } else if (typeId == 'map::string-macro_property' && constantValue is Map) {
    return _asMapMPDecode(constantValue);
  } else if (typeId == 'map::string-list::macro_property' && constantValue is Map) {
    return _asMapOfListMPDecode(constantValue);
  } else if (typeId == 'map::string-list::list::macro_property' && constantValue is Map) {
    return _asMapOfListOfListMPDecode(constantValue);
  }

  return constantValue;
}
