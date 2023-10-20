library selector_plus;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectorPlus<A, T> extends Selector<A, SelectorPlusData<T?>> {
  SelectorPlus({
    Key? key,
    required ValueWidgetBuilder<T?> builder,
    required SelectorPlusData<T?> selector,
    ShouldRebuild<SelectorPlusData>? shouldRebuild,
    Widget? child,
  }) : super(
    key: key,
    builder: (context, value, child) =>
        builder(context, value.value, child),
    selector: (context, value) => selector,
    shouldRebuild: (previous, next) => next.shouldRebuild(),
    child: child,
  );
}

class SelectorListPlus<A, T> extends Selector<A, SelectorListPlusData<T>> {
  SelectorListPlus({
    Key? key,
    required ValueWidgetBuilder<List<T>> builder,
    required SelectorListPlusData<T> selector,
    ShouldRebuild<SelectorListPlusData>? shouldRebuild,
    Widget? child,
  }) : super(
    key: key,
    builder: (context, value, child) =>
        builder(context, value.value, child),
    selector: (context, value) => selector,
    shouldRebuild: (previous, next) => next.shouldRebuild(),
    child: child,
  );
}

class SelectorPlusData<T> {
  T? _value;
  int _version = 0;
  int _lastVersion = -1;

  T? get value => _value;

  SelectorPlusData({Key? key, T? value}) {
    _value = value;
  }

  set value(T? value) {
    _version++;
    _value = value;
  }

  void update() {
    _version++;
  }

  bool shouldRebuild() {
    bool isUpdate = _version != _lastVersion;
    if (isUpdate) {
      _lastVersion = _version;
    }
    return isUpdate;
  }
}

class SelectorListPlusData<T> {
  List<T> _value = [];
  int _version = 0;
  int _lastVersion = -1;

  List<T> get value => _value;

  SelectorListPlusData({Key? key, List<T>? value}) {
    _value = value ?? [];
  }

  set value(List<T> value) {
    _version++;
    _value = value;
  }

  void update() {
    _version++;
  }

  void add(T data) {
    _value.add(data);
    _version++;
  }

  void removeAt(int index) {
    _value.removeAt(index);
    _version++;
  }

  void remove(T data) {
    _value.remove(data);
    _version++;
  }

  bool shouldRebuild() {
    bool isUpdate = _version != _lastVersion;
    if (isUpdate) {
      _lastVersion = _version;
    }
    return isUpdate;
  }
}