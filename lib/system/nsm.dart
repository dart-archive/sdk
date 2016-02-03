// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.dartino._system;

class DartinoNoSuchMethodError implements NoSuchMethodError {
  final Object _receiver;
  final int _receiverClass;
  final int _receiverSelector;

  const DartinoNoSuchMethodError(this._receiver,
                                this._receiverClass,
                                this._receiverSelector);

  String toString() => 'DartinoNoSuchMethodError(selector: $_receiverSelector)';

  // TODO(kustermann): This needs to be implemented.
  StackTrace get stackTrace => null;
}

class DartinoInvocation implements Invocation {
  final Object _receiver;
  final int _receiverClass;
  final int _receiverSelector;

  const DartinoInvocation(this._receiver,
                         this._receiverClass,
                         this._receiverSelector);

  DartinoNoSuchMethodError get asNoSuchMethodError {
    return new DartinoNoSuchMethodError(
        _receiver, _receiverClass, _receiverSelector);
  }

  Symbol get memberName => throw new UnimplementedError();

  List get positionalArguments => throw new UnimplementedError();

  Map<Symbol, dynamic> get namedArguments => throw new UnimplementedError();

  bool get isMethod => throw new UnimplementedError();

  bool get isGetter => throw new UnimplementedError();

  bool get isSetter => throw new UnimplementedError();

  bool get isAccessor => throw new UnimplementedError();
}
