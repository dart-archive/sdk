// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core_patch;

class MiniExpLabel {
  // Initially points to -1 to indicate the label is neither linked (used) nor
  // bound (fixed to a location). When the label is linked, but not bound, it
  // has a negative value, determined by fixupLocation(l), that indicates the
  // location of a reference to it, that will be patched when its location has
  // been bound.  When the label is bound, the negative value is used to patch
  // the chained locations that need patching, and the location is set to the
  // correct location for future use.
  static const NO_LOCATION = -1;
  int _location = NO_LOCATION;

  MiniExpLabel();

  bool get isBound => _location >= 0;

  void bind(List<int> codes) {
    assert(!isBound);
    int l = codes.length;
    for (int forwardReference = _location; forwardReference != NO_LOCATION; ) {
      int patchLocation = _decodeFixup(forwardReference);
      forwardReference = codes[patchLocation];
      codes[patchLocation] = l;
    }
    _location = l;
  }

  int get location {
    assert(isBound);
    return _location;
  }

  // The negative value is -(location + 2) so as to avoid NO_LOCATION, which is
  // -1.
  int _encodeFixup(int location) => -(location + 2);
  // It's perhaps not intuitive that the encoding and decoding functions are
  // identical, but they are both just mirroring around -1.
  int _decodeFixup(int encoded) => -(encoded + 2);

  void link(List<int> codes) {
    int value = _location;
    if (!isBound) _location = _encodeFixup(codes.length);
    // If the label is bound, this writes the correct (positive) location.
    // Otherwise it writes the previous link in the chain of forward references
    // that need fixing when the label is bound.
    codes.add(value);
  }
}

// Registers.
const ZERO_REGISTER = 0;
const NO_POSITION_REGISTER = 1;
const CURRENT_POSITION = 2;
const STRING_LENGTH = 3;
const STACK_POINTER = 4;
const FIXED_REGISTERS = 5;

const REGISTER_NAMES = const <String>[
  "ZERO",
  "NO_POSITION_REGISTER",
  "CURRENT_POSITION",
  "STRING_LENGTH",
  "STACK_POINTER",
  "TEMP_0",
  "TEMP_1",
  "TEMP_2",
  "TEMP_3",
  "TEMP_4",
  "TEMP_5",
  "TEMP_6",
  "TEMP_7",
  "TEMP_8",
  "TEMP_9",
  "TEMP_10",
  "TEMP_11",
  "TEMP_12",
  "TEMP_13",
  "TEMP_14",
  "TEMP_15"
];

// Used for capture registers that have not captured any position in the
// string.
const NO_POSITION = -1;

// Byte codes.
const GOTO = 0;  // label
const PUSH_REGISTER = 1;  // reg
const PUSH_BACKTRACK = 2;  // const
const POP_REGISTER = 3;  // reg
const BACKTRACK_EQ = 4;  // reg reg
const BACKTRACK_NE = 5;  // reg reg
const BACKTRACK_GT = 6;  // reg reg
const BACKTRACK_IF_NO_MATCH = 7;  // constant-pool-offset
const BACKTRACK_IF_IN_RANGE = 8;  // from to
const GOTO_IF_MATCH = 9;  // charCode label
const GOTO_IF_IN_RANGE = 10;  // from to label
const GOTO_EQ = 11; // reg reg label
const GOTO_GE = 12; // reg reg label
const GOTO_IF_WORD_CHARACTER = 13;  // position-offset label
const ADD_TO_REGISTER = 14; // reg const
const COPY_REGISTER = 15; // dest-reg source-reg
const BACKTRACK = 16;
const SUCCEED = 17;
const FAIL = 18;

// Format is name, number of register arguments, number of other arguments.
const BYTE_CODE_NAMES = const [
  "GOTO", 0, 1,
  "PUSH_REGISTER", 1, 0,
  "PUSH_BACKTRACK", 0, 1,
  "POP_REGISTER", 1, 0,
  "BACKTRACK_EQ", 2, 0,
  "BACKTRACK_NE", 2, 0,
  "BACKTRACK_GT", 2, 0,
  "BACKTRACK_IF_NO_MATCH", 0, 1,
  "BACKTRACK_IF_IN_RANGE", 0, 2,
  "GOTO_IF_MATCH", 0, 2,
  "GOTO_IF_IN_RANGE", 0, 3,
  "GOTO_EQ", 2, 1,
  "GOTO_GE", 2, 1,
  "GOTO_IF_WORD_CHARACTER", 0, 2,
  "ADD_TO_REGISTER", 1, 1,
  "COPY_REGISTER", 2, 0,
  "BACKTRACK", 0, 0,
  "SUCCEED", 0, 0,
  "FAIL", 0, 0];

const CHAR_CODE_NUL = 0;
const CHAR_CODE_BACKSPACE = 8;
const CHAR_CODE_TAB = 9;
const CHAR_CODE_NEWLINE = 10;
const CHAR_CODE_VERTICAL_TAB = 11;
const CHAR_CODE_FORM_FEED = 12;
const CHAR_CODE_CARRIAGE_RETURN = 13;
const CHAR_CODE_SPACE = 32;
const CHAR_CODE_BANG = 33;
const CHAR_CODE_ASTERISK = 42;
const CHAR_CODE_PLUS = 43;
const CHAR_CODE_COMMA = 44;
const CHAR_CODE_DASH = 45;
const CHAR_CODE_0 = 48;
const CHAR_CODE_9 = 57;
const CHAR_CODE_COLON = 58;
const CHAR_CODE_EQUALS = 61;
const CHAR_CODE_QUERY = 63;
const CHAR_CODE_UPPER_A = 65;
const CHAR_CODE_UPPER_B = 66;
const CHAR_CODE_UPPER_D = 68;
const CHAR_CODE_UPPER_F = 70;
const CHAR_CODE_UPPER_S = 83;
const CHAR_CODE_UPPER_W = 87;
const CHAR_CODE_UPPER_Z = 90;
const CHAR_CODE_BACKSLASH = 92;
const CHAR_CODE_R_SQUARE = 93;
const CHAR_CODE_CARET = 94;
const CHAR_CODE_UNDERSCORE = 95;
const CHAR_CODE_LOWER_A = 97;
const CHAR_CODE_LOWER_B = 98;
const CHAR_CODE_LOWER_D = 100;
const CHAR_CODE_LOWER_F = 102;
const CHAR_CODE_LOWER_N = 110;
const CHAR_CODE_LOWER_R = 114;
const CHAR_CODE_LOWER_S = 115;
const CHAR_CODE_LOWER_T = 116;
const CHAR_CODE_LOWER_U = 117;
const CHAR_CODE_LOWER_V = 118;
const CHAR_CODE_LOWER_W = 119;
const CHAR_CODE_LOWER_X = 120;
const CHAR_CODE_LOWER_Z = 122;
const CHAR_CODE_L_BRACE = 123;
const CHAR_CODE_R_BRACE = 125;
const CHAR_CODE_NO_BREAK_SPACE = 0xa0;
const CHAR_CODE_OGHAM_SPACE_MARK = 0x1680;
const CHAR_CODE_EN_QUAD = 0x2000;
const CHAR_CODE_HAIR_SPACE = 0x200a;
const CHAR_CODE_LINE_SEPARATOR = 0x2028;
const CHAR_CODE_PARAGRAPH_SEPARATOR = 0x2029;
const CHAR_CODE_NARROW_NO_BREAK_SPACE = 0x202f;
const CHAR_CODE_MEDIUM_MATHEMATICAL_SPACE = 0x205f;
const CHAR_CODE_IDEOGRAPHIC_SPACE = 0x3000;
const CHAR_CODE_ZERO_WIDTH_NO_BREAK_SPACE = 0xfeff;

class MiniExpCompiler {
  final String pattern;
  final bool caseSensitive;
  final List<int> registers = new List<int>();
  int captureRegisterCount = 0;
  int firstCaptureRegister;
  final List<int> _codes = new List<int>();
  final List<int> _extraConstants = new List<int>();
  MiniExpLabel _pendingGoto;

  MiniExpCompiler(this.pattern, this.caseSensitive) {
    for (int i = 0; i < FIXED_REGISTERS; i++) {
      registers.add(i == NO_POSITION_REGISTER ? NO_POSITION : 0);
    }
  }

  List<int> get codes {
    flushPendingGoto();
    return _codes;
  }

  String get constantPool {
    if (_extraConstants.isEmpty) {
      return pattern;
    } else {
      return pattern + new String.fromCharCodes(_extraConstants);
    }
  }

  int constantPoolEntry(int index) {
    if (index < pattern.length) return pattern.codeUnitAt(index);
    return _extraConstants[index - pattern.length];
  }

  void _emit(int code, [int arg1, int arg2]) {
    flushPendingGoto();
    _codes.add(code);
    if (arg1 != null) _codes.add(arg1);
    if (arg2 != null) _codes.add(arg2);
  }

  void generate(MiniExpAst ast, MiniExpLabel onSuccess) {
    bind(ast.label);
    ast.generate(this, onSuccess);
  }

  void bind(MiniExpLabel label) {
    if (label == _pendingGoto) {
      _pendingGoto = null;  // Peephole optimization.
    }
    flushPendingGoto();
    label.bind(_codes);
  }

  void link(MiniExpLabel label) => label.link(_codes);

  void succeed() => _emit(SUCCEED);

  void fail() => _emit(FAIL);

  int allocateWorkingRegister() => allocateConstantRegister(0);

  int allocateConstantRegister(int value) {
    int register = registers.length;
    registers.add(value);
    return register;
  }

  // Returns negative numbers, starting at -1. This is so that we can
  // interleave allocation of capture registers and regular registers, but
  // still end up with the capture registers being contiguous.
  int allocateCaptureRegisters() {
    captureRegisterCount += 2;
    return -captureRegisterCount + 1;
  }

  void addCaptureRegisters() {
    firstCaptureRegister = registers.length;
    for (int i = 0; i < captureRegisterCount; i++) {
      registers.add(NO_POSITION);
    }
  }

  // Raw register numbers are negative for capture registers, positive for
  // constant and working registers.
  int registerNumber(int rawRegisterNumber) {
    if (rawRegisterNumber >= 0) return rawRegisterNumber;
    return -(rawRegisterNumber + 1) + firstCaptureRegister;
  }

  int addToConstantPool(int codeUnit) {
    _extraConstants.add(codeUnit);
    return _extraConstants.length - 1;
  }

  void pushBacktrack(MiniExpLabel label) {
    _emit(PUSH_BACKTRACK);
    link(label);
  }

  void backtrack() {
    _emit(BACKTRACK);
  }

  void push(int reg) {
    _emit(PUSH_REGISTER, registerNumber(reg));
  }

  void pop(int reg) {
    _emit(POP_REGISTER, registerNumber(reg));
  }

  void goto(MiniExpLabel label) {
    if (_pendingGoto != label) flushPendingGoto();
    _pendingGoto = label;
  }

  void flushPendingGoto() {
    if (_pendingGoto != null) {
      _codes.add(GOTO);
      link(_pendingGoto);
      _pendingGoto = null;
    }
  }

  void backtrackIfEqual(int register1, int register2) {
    _emit(BACKTRACK_EQ, registerNumber(register1), registerNumber(register2));
  }

  void backtrackIfNotEqual(int register1, int register2) {
    _emit(BACKTRACK_NE, registerNumber(register1), registerNumber(register2));
  }

  void addToRegister(int reg, int offset) {
    _emit(ADD_TO_REGISTER, registerNumber(reg), offset);
  }

  void copyRegister(int destRegister, int sourceRegister) {
    _emit(COPY_REGISTER, registerNumber(destRegister),
        registerNumber(sourceRegister));
  }

  void backtrackIfGreater(int register1, int register2) {
    _emit(BACKTRACK_GT, registerNumber(register1), registerNumber(register2));
  }

  void gotoIfGreaterEqual(int register1, int register2, MiniExpLabel label) {
    _emit(GOTO_GE, registerNumber(register1), registerNumber(register2));
    link(label);
  }

  void backtrackIfNoMatch(int constant_pool_offset) {
    _emit(BACKTRACK_IF_NO_MATCH, constant_pool_offset);
  }

  void backtrackIfInRange(int from, int to) {
    _emit(BACKTRACK_IF_IN_RANGE, from, to);
  }

  void gotoIfMatches(int charCode, MiniExpLabel label) {
    _emit(GOTO_IF_MATCH, charCode);
    link(label);
  }

  void gotoIfInRange(int from, int to, MiniExpLabel label) {
    if (from == to) {
      gotoIfMatches(from, label);
    } else {
      _emit(GOTO_IF_IN_RANGE, from, to);
      link(label);
    }
  }

  void backtrackIfNotAtWordBoundary() {
    MiniExpLabel non_word_on_left = new MiniExpLabel();
    MiniExpLabel word_on_left = new MiniExpLabel();
    MiniExpLabel at_word_boundary = new MiniExpLabel();
    MiniExpLabel do_backtrack = new MiniExpLabel();

    _emit(GOTO_EQ, CURRENT_POSITION, ZERO_REGISTER);
    link(non_word_on_left);
    _emit(GOTO_IF_WORD_CHARACTER, -1);
    link(word_on_left);

    bind(non_word_on_left);
    _emit(BACKTRACK_EQ, CURRENT_POSITION, STRING_LENGTH);
    _emit(GOTO_IF_WORD_CHARACTER, 0);
    link(at_word_boundary);
    bind(do_backtrack);
    backtrack();

    bind(word_on_left);
    _emit(GOTO_EQ, CURRENT_POSITION, STRING_LENGTH);
    link(at_word_boundary);
    _emit(GOTO_IF_WORD_CHARACTER, 0);
    link(do_backtrack);

    bind(at_word_boundary);
  }
}

// MiniExpAnalysis objects reflect properties of an AST subtree.  They are
// immutable and are reused to some extent.
class MiniExpAnalysis {
  // Can this subtree match an empty string?  If we know that's not possible,
  // we can optimize away the test that ensures we are making progress when we
  // match repetitions.
  final bool canMatchEmpty;

  // Set to null if the AST does not match something with a fixed length.  That
  // fixed length thing has to be something that does not touch the stack.  This
  // is an important optimization that prevents .* from using huge amounts of
  // stack space when running.
  final int fixedLength;

  // Can this subtree only match at the start of the regexp?  Can't pass all
  // tests without being able to spot this.
  final bool anchored;

  // Allows the AST to notify a surrounding loop (a quantifier higher up the
  // tree) that it has registers it expects to be saved on the back edge.
  final List<int> registersToSave;

  static List<int> combineRegisters(List<int> left, List<int> right) {
    if (right == null || right.isEmpty) {
      return left;
    } else if (left == null || left.isEmpty) {
      return right;
    } else {
      return new List<int>()..addAll(left)..addAll(right);
    }
  }

  static int combineFixedLengths(MiniExpAnalysis left, MiniExpAnalysis right) {
    if (left.fixedLength == null || right.fixedLength == null) {
      return null;
    } else {
      return left.fixedLength + right.fixedLength;
    }
  }

  MiniExpAnalysis.or(MiniExpAnalysis left, MiniExpAnalysis right)
      : canMatchEmpty = left.canMatchEmpty || right.canMatchEmpty,
        // Even if both alternatives are the same length we can't handle a
        // disjunction without pushing backtracking information on the stack.
        fixedLength = null,
        anchored = left.anchored && right.anchored,
        registersToSave =
            combineRegisters(left.registersToSave, right.registersToSave);

  MiniExpAnalysis.and(MiniExpAnalysis left, MiniExpAnalysis right)
      : canMatchEmpty = left.canMatchEmpty && right.canMatchEmpty,
        fixedLength = combineFixedLengths(left, right),
        anchored = left.anchored,
        registersToSave =
            combineRegisters(left.registersToSave, right.registersToSave);

  const MiniExpAnalysis.empty()
      : canMatchEmpty = true,
        fixedLength = 0,
        anchored = false,
        registersToSave = null;

  const MiniExpAnalysis.atStart()
      : canMatchEmpty = true,
        fixedLength = 0,
        anchored = true,
        registersToSave = null;

  MiniExpAnalysis.lookahead(MiniExpAnalysis bodyAnalysis, bool positive)
      : canMatchEmpty = true,
        fixedLength = 0,
        anchored = positive && bodyAnalysis.anchored,
        registersToSave = bodyAnalysis.registersToSave;

  MiniExpAnalysis.quantifier(
      MiniExpAnalysis bodyAnalysis, int min, int max, List<int> regs)
      : canMatchEmpty = min == 0 || bodyAnalysis.canMatchEmpty,
        fixedLength = (min == 1 && max == 1) ? bodyAnalysis.fixedLength : null,
        anchored = min > 0 && bodyAnalysis.anchored,
        registersToSave = combineRegisters(bodyAnalysis.registersToSave, regs);

  const MiniExpAnalysis.atom()
      : canMatchEmpty = false,
        fixedLength = 1,
        anchored = false,
        registersToSave = null;

  const MiniExpAnalysis.knowNothing()
      : canMatchEmpty = true,
        fixedLength = null,
        anchored = false,
        registersToSave = null;

  MiniExpAnalysis.capture(MiniExpAnalysis bodyAnalysis, int start, int end)
      : canMatchEmpty = bodyAnalysis.canMatchEmpty,
        // We can't generate a capture without pushing backtracking information
        // on the stack.
        fixedLength = null,
        anchored = bodyAnalysis.anchored,
        registersToSave =
            combineRegisters(bodyAnalysis.registersToSave, <int>[start, end]);
}

abstract class MiniExpAst {
  // When generating code for an AST, note that:
  // * The previous code may fall through to this AST, but it might also
  //   branch to it.  The label has always been bound just before generate()
  //   is called.
  // * It's not permitted to fall through to the bottom of the generated
  //   code. Always end with backtrack or a goto(onSuccess).
  // * You can push any number of backtrack pairs (PC, position), but if you
  //   push anything else, then you have to push a backtrack location that will
  //   clean it up.  On entry you can assume there is a backtrack pair on the
  //   top of the stack.
  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess);

  MiniExpAnalysis analyze(MiniExpCompiler);

  // Label is bound at the entry point for the AST tree.
  final MiniExpLabel label = new MiniExpLabel();
}

class Disjunction extends MiniExpAst {
  final MiniExpAst _left;
  final MiniExpAst _right;

  Disjunction(MiniExpAst this._left, MiniExpAst this._right);

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    MiniExpLabel tryRight = new MiniExpLabel();
    compiler.pushBacktrack(tryRight);
    compiler.generate(_left, onSuccess);
    compiler.bind(tryRight);
    compiler.generate(_right, onSuccess);
  }

  MiniExpAnalysis analyze(MiniExpCompiler compiler) {
    return new MiniExpAnalysis.or(
        _left.analyze(compiler), _right.analyze(compiler));
  }
}

class EmptyAlternative extends MiniExpAst {
  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    compiler.goto(onSuccess);
  }

  MiniExpAnalysis analyze(MiniExpCompiler compiler) {
    return const MiniExpAnalysis.empty();
  }
}

class Alternative extends MiniExpAst {
  final MiniExpAst _left;
  final MiniExpAst _right;

  Alternative(this._left, this._right);

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    compiler.generate(_left, _right.label);
    compiler.generate(_right, onSuccess);
  }

  MiniExpAnalysis analyze(MiniExpCompiler compiler) {
    return new MiniExpAnalysis.and(
        _left.analyze(compiler), _right.analyze(compiler));
  }
}

abstract class Assertion extends MiniExpAst {
  MiniExpAnalysis analyze(MiniExpCompiler) => const MiniExpAnalysis.empty();
}

class AtStart extends Assertion {
  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    compiler.backtrackIfNotEqual(CURRENT_POSITION, ZERO_REGISTER);
    compiler.goto(onSuccess);
  }

  MiniExpAnalysis analyze(MiniExpCompiler) => const MiniExpAnalysis.atStart();
}

class AtEnd extends Assertion {
  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    compiler.backtrackIfNotEqual(CURRENT_POSITION, STRING_LENGTH);
    compiler.goto(onSuccess);
  }
}

abstract class MultiLineAssertion extends Assertion {
  void backtrackIfNotNewline(MiniExpCompiler compiler) {
    compiler.backtrackIfInRange(
        CHAR_CODE_CARRIAGE_RETURN + 1, CHAR_CODE_LINE_SEPARATOR - 1);
    compiler.backtrackIfInRange(0, CHAR_CODE_NEWLINE - 1);
    compiler.backtrackIfInRange(
        CHAR_CODE_NEWLINE + 1, CHAR_CODE_CARRIAGE_RETURN - 1);
    compiler.backtrackIfInRange(CHAR_CODE_PARAGRAPH_SEPARATOR + 1, 0xffff);
  }
}

class AtBeginningOfLine extends MultiLineAssertion {
  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    compiler.gotoIfGreaterEqual(ZERO_REGISTER, CURRENT_POSITION, onSuccess);
    // We need to look one back to see if there was a newline there.  If we
    // backtrack, then that also restores the current position, but if we don't
    // backtrack, we have to fix it again.
    compiler.addToRegister(CURRENT_POSITION, -1);
    backtrackIfNotNewline(compiler);
    compiler.addToRegister(CURRENT_POSITION, 1);
    compiler.goto(onSuccess);
  }
}

class AtEndOfLine extends MultiLineAssertion {
  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    compiler.gotoIfGreaterEqual(CURRENT_POSITION, STRING_LENGTH, onSuccess);
    backtrackIfNotNewline(compiler);
    compiler.goto(onSuccess);
  }
}

class WordBoundary extends Assertion {
  final bool _positive;

  WordBoundary(this._positive);

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    // Positive word boundaries are much more common that negative ones, so we
    // will allow ourselves to generate some pretty horrible code for the
    // negative ones.
    if (!_positive) {
      compiler.pushBacktrack(onSuccess);
    }
    compiler.backtrackIfNotAtWordBoundary();
    if (_positive) {
      compiler.goto(onSuccess);
    } else {
      // Pop the two stack position of the unneeded backtrack.
      compiler.pop(CURRENT_POSITION);
      compiler.pop(CURRENT_POSITION);
      // This overwrites the current position with the correct value.
      compiler.backtrack();
    }
  }
}

class LookAhead extends Assertion {
  final bool _positive;
  final MiniExpAst _body;

  int _savedStackPointerRegister;
  int _savedPosition;

  LookAhead(this._positive, this._body, MiniExpCompiler compiler) {
    _savedStackPointerRegister = compiler.allocateWorkingRegister();
    _savedPosition = compiler.allocateWorkingRegister();
  }

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    // Lookahead.  Even if the subexpression succeeds, the current position is
    // reset, and the backtracking stack is unwound so that we can never
    // backtrack into the lookahead.  On a failure of the subexpression, the
    // stack will be naturally unwound.
    MiniExpLabel body_succeeded = new MiniExpLabel();
    MiniExpLabel succeed_on_failure = new MiniExpLabel();
    compiler.copyRegister(_savedStackPointerRegister, STACK_POINTER);
    compiler.copyRegister(_savedPosition, CURRENT_POSITION);
    if (!_positive) {
      compiler.pushBacktrack(succeed_on_failure);
    }
    compiler.generate(_body, body_succeeded);

    compiler.bind(body_succeeded);
    compiler.copyRegister(STACK_POINTER, _savedStackPointerRegister);
    compiler.copyRegister(CURRENT_POSITION, _savedPosition);
    if (_positive) {
      compiler.goto(onSuccess);
    } else {
      compiler.backtrack();
      compiler.bind(succeed_on_failure);
      compiler.goto(onSuccess);
    }
  }

  MiniExpAnalysis analyze(compiler) {
    return new MiniExpAnalysis.lookahead(_body.analyze(compiler), _positive);
  }
}

class Quantifier extends MiniExpAst {
  final int _min;
  final int _max;
  final bool _greedy;
  final MiniExpAst _body;
  int _counterRegister;
  int _startOfMatchRegister;  // Implements 21.2.2.5.1 note 4.
  int _minRegister;
  int _maxRegister;
  List<int> _subtreeRegistersThatNeedSaving;
  int _optimizedGreedyRegister;
  int _savePositionRegister;
  int _bodyLength;

  bool get _isOptimizedGreedy => _optimizedGreedyRegister != null;

  Quantifier(this._min,
             this._max,
             this._greedy,
             this._body,
             MiniExpCompiler compiler) {
    if (_counterCheck) {
      _counterRegister = compiler.allocateWorkingRegister();
      _minRegister = compiler.allocateConstantRegister(_min);
      _maxRegister = compiler.allocateConstantRegister(_max);
    }
  }

  // We fall through to the top of this, when it is time to match the body of
  // the quantifier.  If the body matches successfully, we should go to
  // onBodySuccess, otherwise clean up and backtrack.
  void generateCommon(
      MiniExpCompiler compiler, MiniExpLabel onBodySuccess) {
    bool needToCatchDidntMatch = _greedy || _bodyCanMatchEmpty ||
        _counterCheck || _saveAndRestoreRegisters;
    MiniExpLabel didntMatch = new MiniExpLabel();

    if (_saveAndRestoreRegisters) {
      for (int reg in _subtreeRegistersThatNeedSaving) {
        compiler.push(reg);
        compiler.copyRegister(reg, NO_POSITION_REGISTER);
      }
    }

    if (_bodyCanMatchEmpty) {
      compiler.push(_startOfMatchRegister);
      compiler.copyRegister(_startOfMatchRegister, CURRENT_POSITION);
    }

    if (needToCatchDidntMatch) {
      compiler.pushBacktrack(didntMatch);
    }

    if (_counterCheck) {
      compiler.addToRegister(_counterRegister, 1);
      if (_maxCheck) {
        compiler.backtrackIfGreater(_counterRegister, _maxRegister);
      }
    }

    compiler.generate(_body, onBodySuccess);

    if (needToCatchDidntMatch) {
      compiler.bind(didntMatch);
      if (_bodyCanMatchEmpty) {
        compiler.pop(_startOfMatchRegister);
      }
      if (_counterCheck) {
        compiler.addToRegister(_counterRegister, -1);
      }
      if (_saveAndRestoreRegisters) {
        for (int i = _subtreeRegistersThatNeedSaving.length - 1; i >= 0; --i) {
          compiler.pop(_subtreeRegistersThatNeedSaving[i]);
        }
      }
      if (!_greedy) compiler.backtrack();
    }
  }

  void generateFixedLengthGreedy(
      MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    MiniExpLabel newIteration = new MiniExpLabel();
    MiniExpLabel cantAdvanceMore = new MiniExpLabel();
    MiniExpLabel continuationFailed = new MiniExpLabel();

    // Save the current position, so we know when the quantifier has been
    // unwound enough.
    compiler.copyRegister(_optimizedGreedyRegister, CURRENT_POSITION);
    if (_min != 0) {
      compiler.addToRegister(_optimizedGreedyRegister, _min * _bodyLength);
    }

    // This backtrack doesn't trigger until the quantifier has eaten as much as
    // possible.  Unfortunately, whenever we backtrack in this simple system,
    // the old current position in the subject string is also rewound.  That's
    // not so convenient here, so we will have to save the current position in
    // a special register.  It would be faster to generate the body in a
    // special mode where we use a different backtrack instruction that just
    // rewinds the current position a certain number of characters instead of
    // popping it.
    compiler.pushBacktrack(cantAdvanceMore);

    // The loop.
    compiler.bind(newIteration);
    compiler.copyRegister(_savePositionRegister, CURRENT_POSITION);
    compiler.generate(_body, newIteration);

    // The greedy quantifier has eaten as much as it can.  Time to try the
    // continuation of the regexp after the quantifier.
    compiler.bind(cantAdvanceMore);

    if (_min != 0) {
      compiler.backtrackIfGreater(
          _optimizedGreedyRegister, _savePositionRegister);
    }

    compiler.addToRegister(_savePositionRegister, _bodyLength);
    compiler.copyRegister(CURRENT_POSITION, _savePositionRegister);

    // The continuation of the regexp failed.  We backtrack the greedy
    // quantifier by one step and retry.
    compiler.bind(continuationFailed);
    compiler.addToRegister(CURRENT_POSITION, -_bodyLength);
    // If we got back to where the quantifier started matching, then jump
    // to the continuation (we haven't pushed a backtrack, so if that fails, it
    // will backtrack further).
    // We don't have gotoIfEqual, so use gotoIfGreaterEqual.
    compiler.gotoIfGreaterEqual(
        _optimizedGreedyRegister, CURRENT_POSITION, onSuccess);
    compiler.pushBacktrack(continuationFailed);
    compiler.goto(onSuccess);
  }

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    // We optimize loops of the form .* to avoid big backtrack stacks.
    if (_isOptimizedGreedy) {
      generateFixedLengthGreedy(compiler, onSuccess);
      return;
    }
    if (_min == 1 && _max == 1) {
      compiler.generate(_body, onSuccess);
      return;
    }
    // The above means if _max is 1 then _min must be 0, which simplifies
    // things.
    MiniExpLabel bodyMatched = _max == 1 ? onSuccess : new MiniExpLabel();
    MiniExpLabel checkEmptyMatchLabel;
    MiniExpLabel onBodySuccess = bodyMatched;
    if (_bodyCanMatchEmpty) {
      checkEmptyMatchLabel = new MiniExpLabel();
      onBodySuccess = checkEmptyMatchLabel;
    }
    if (_counterCheck) {
      compiler.copyRegister(_counterRegister, ZERO_REGISTER);
    }

    if (bodyMatched != onSuccess) {
      compiler.bind(bodyMatched);
    }

    if (_greedy) {
      generateCommon(compiler, onBodySuccess);

      if (_minCheck) {
        compiler.gotoIfGreaterEqual(_counterRegister, _minRegister, onSuccess);
        compiler.backtrack();
      } else {
        compiler.goto(onSuccess);
      }
    } else {
      // Non-greedy.
      MiniExpLabel tryBody = new MiniExpLabel();

      if (_minCheck) {
        // If there's a minimum and we haven't reached it we should not try to
        // run the continuation, but go straight to the _body.
        // TODO(erikcorry): if we had a gotoIfLess we could save instructions
        // here.
        MiniExpLabel jumpToContinuation = new MiniExpLabel();
        compiler.gotoIfGreaterEqual(
            _counterRegister, _minRegister, jumpToContinuation);
        compiler.goto(tryBody);
        compiler.bind(jumpToContinuation);
      }
      // If the continuation fails, we can try the _body once more.
      compiler.pushBacktrack(tryBody);
      compiler.goto(onSuccess);

      // We failed to match the continuation, so lets match the _body once more
      // and then try again.
      compiler.bind(tryBody);
      generateCommon(compiler, onBodySuccess);
    }

    if (_bodyCanMatchEmpty) {
      compiler.bind(checkEmptyMatchLabel);
      if (_minCheck) {
        compiler.gotoIfGreaterEqual(
            _minRegister, _counterRegister, bodyMatched);
      }
      compiler.backtrackIfEqual(_startOfMatchRegister, CURRENT_POSITION);
      compiler.goto(bodyMatched);
    }
  }

  MiniExpAnalysis analyze(compiler) {
    MiniExpAnalysis bodyAnalysis = _body.analyze(compiler);
    _subtreeRegistersThatNeedSaving = bodyAnalysis.registersToSave;
    _bodyLength = bodyAnalysis.fixedLength;
    if (bodyAnalysis.canMatchEmpty) {
      _startOfMatchRegister = compiler.allocateWorkingRegister();
    } else if (_max == null && _greedy && _bodyLength != null) {
      // This also put us in a mode where code is generated differently for
      // this AST.
      _optimizedGreedyRegister = compiler.allocateWorkingRegister();
      _savePositionRegister = compiler.allocateWorkingRegister();
    }
    List<int> myRegs = [
        _counterRegister, _optimizedGreedyRegister, _savePositionRegister]
            .where((x) => x != null).toList(growable: false);
    return new MiniExpAnalysis.quantifier(bodyAnalysis, _min, _max, myRegs);
  }

  bool get _maxCheck => _max != 1 && _max != null;

  bool get _minCheck => _min != 0;

  bool get _counterCheck => _maxCheck || _minCheck;

  bool get _bodyCanMatchEmpty => _startOfMatchRegister != null;

  bool get _saveAndRestoreRegisters {
    return _subtreeRegistersThatNeedSaving != null &&
           !_subtreeRegistersThatNeedSaving.isEmpty;
  }
}

class Atom extends MiniExpAst {
  final int _constantIndex;

  Atom(this._constantIndex);

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    compiler.backtrackIfEqual(CURRENT_POSITION, STRING_LENGTH);
    MiniExpLabel match;
    int charCode = compiler.constantPoolEntry(_constantIndex);
    if (!compiler.caseSensitive) {
      List<int> equivalents = internalRegExpEquivalenceClass(charCode);
      if (equivalents != null && equivalents.length > 1) {
        match = new MiniExpLabel();
        for (int equivalent in equivalents) {
          if (equivalent == charCode) continue;
          compiler.gotoIfMatches(equivalent, match);
        }
      }
    }
    compiler.backtrackIfNoMatch(_constantIndex);
    if (match != null) compiler.bind(match);
    compiler.addToRegister(CURRENT_POSITION, 1);
    compiler.goto(onSuccess);
  }

  MiniExpAnalysis analyze(compiler) => const MiniExpAnalysis.atom();
}

class CharClass extends MiniExpAst {
  final List<int> _ranges = new List<int>();
  final bool _positive;

  CharClass(this._positive);

  // Here and elsewhere, "to" is inclusive.
  void add(int from, int to) {
    _ranges.add(from);
    _ranges.add(to);
  }

  static const List<int> _spaceCodes = const <int>[
    -1,
    CHAR_CODE_TAB, CHAR_CODE_CARRIAGE_RETURN,
    CHAR_CODE_SPACE, CHAR_CODE_SPACE,
    CHAR_CODE_NO_BREAK_SPACE, CHAR_CODE_NO_BREAK_SPACE,
    CHAR_CODE_OGHAM_SPACE_MARK, CHAR_CODE_OGHAM_SPACE_MARK,
    CHAR_CODE_EN_QUAD, CHAR_CODE_HAIR_SPACE,
    CHAR_CODE_LINE_SEPARATOR, CHAR_CODE_PARAGRAPH_SEPARATOR,
    CHAR_CODE_NARROW_NO_BREAK_SPACE, CHAR_CODE_NARROW_NO_BREAK_SPACE,
    CHAR_CODE_MEDIUM_MATHEMATICAL_SPACE, CHAR_CODE_MEDIUM_MATHEMATICAL_SPACE,
    CHAR_CODE_IDEOGRAPHIC_SPACE, CHAR_CODE_IDEOGRAPHIC_SPACE,
    CHAR_CODE_ZERO_WIDTH_NO_BREAK_SPACE, CHAR_CODE_ZERO_WIDTH_NO_BREAK_SPACE,
    0x10000];

  void addSpaces() {
    for (int i = 1; i < _spaceCodes.length - 1; i += 2) {
      add(_spaceCodes[i], _spaceCodes[i + 1]);
    }
  }

  void addNotSpaces() {
    for (int i = 0; i < _spaceCodes.length; i += 2) {
      add(_spaceCodes[i] + 1, _spaceCodes[i + 1] - 1);
    }
  }

  void addSpecial(charCode) {
    if (charCode == CHAR_CODE_LOWER_D) {
      add(CHAR_CODE_0, CHAR_CODE_9);
    } else if (charCode == CHAR_CODE_UPPER_D) {
      add(0, CHAR_CODE_0 - 1);
      add(CHAR_CODE_9 + 1, 0xffff);
    } else if (charCode == CHAR_CODE_LOWER_S) {
      addSpaces();
    } else if (charCode == CHAR_CODE_UPPER_S) {
      addNotSpaces();
    } else if (charCode == CHAR_CODE_LOWER_W) {
      add(CHAR_CODE_0, CHAR_CODE_9);
      add(CHAR_CODE_UPPER_A, CHAR_CODE_UPPER_Z);
      add(CHAR_CODE_UNDERSCORE, CHAR_CODE_UNDERSCORE);
      add(CHAR_CODE_LOWER_A, CHAR_CODE_LOWER_Z);
    } else if (charCode == CHAR_CODE_UPPER_W) {
      add(0, CHAR_CODE_0 - 1 );
      add(CHAR_CODE_9 + 1, CHAR_CODE_UPPER_A - 1);
      add(CHAR_CODE_UPPER_Z + 1, CHAR_CODE_UNDERSCORE - 1);
      add(CHAR_CODE_UNDERSCORE + 1, CHAR_CODE_LOWER_A - 1);
      add(CHAR_CODE_LOWER_Z + 1, 0xffff);
    }
  }

  List<int> caseInsensitiveRanges(List<int> oldRanges) {
    List<int> ranges = new List<int>();
    for (int i = 0; i < oldRanges.length; i += 2) {
      int start = oldRanges[i];
      int end = oldRanges[i + 1];
      int previousStart = -1;
      int previousEnd = -1;
      for (int j = start; j <= end; j++) {
        List<int> equivalents = internalRegExpEquivalenceClass(j);
        if (equivalents != null && equivalents.length > 1) {
          for (int equivalent in equivalents) {
            if ((equivalent < start || equivalent > end) &&
                (equivalent < previousStart || equivalent > previousEnd)) {
              if (equivalent == previousEnd + 1) {
                previousEnd = ranges[ranges.length - 1] = equivalent;
              } else {
                ranges.add(equivalent);
                ranges.add(equivalent);
                previousStart = equivalent;
                previousEnd = equivalent;
              }
            }
          }
        }
      }
      ranges.add(start);
      ranges.add(end);
    }
    // TODO(erikcorry): Sort and merge ranges.
    return ranges;
  }

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    compiler.backtrackIfEqual(CURRENT_POSITION, STRING_LENGTH);
    List<int> ranges = _ranges;
    if (!compiler.caseSensitive) {
      ranges = caseInsensitiveRanges(_ranges);
    }
    MiniExpLabel match = new MiniExpLabel();
    if (_positive) {
      for (int i = 0; i < ranges.length; i += 2) {
        compiler.gotoIfInRange(ranges[i], ranges[i + 1], match);
      }
      compiler.backtrack();
      compiler.bind(match);
    } else {
      for (int i = 0; i < ranges.length; i += 2) {
        compiler.backtrackIfInRange(ranges[i], ranges[i + 1]);
      }
    }
    compiler.addToRegister(CURRENT_POSITION, 1);
    compiler.goto(onSuccess);
  }

  MiniExpAnalysis analyze(compiler) => const MiniExpAnalysis.atom();
}

class BackReference extends MiniExpAst {
  int _backReferenceIndex;

  BackReference(this._backReferenceIndex);

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    // TODO(erikcorry): Implement.
    throw("Back references not yet implemented");
    compiler.goto(onSuccess);
  }

  MiniExpAnalysis analyze(compiler) => const MiniExpAnalysis.knowNothing();
}

class Capture extends MiniExpAst {
  final int _captureCount;
  final MiniExpAst _body;
  int _startRegister;
  int _endRegister;

  Capture(this._captureCount, MiniExpAst this._body);

  void allocateRegisters(MiniExpCompiler compiler) {
    if (_startRegister == null) {
      _startRegister = compiler.allocateCaptureRegisters();
      _endRegister = _startRegister - 1;
    }
  }

  void generate(MiniExpCompiler compiler, MiniExpLabel onSuccess) {
    MiniExpLabel undoStart = new MiniExpLabel();
    MiniExpLabel writeEnd = new MiniExpLabel();
    MiniExpLabel undoEnd = new MiniExpLabel();
    compiler.copyRegister(_startRegister, CURRENT_POSITION);
    compiler.pushBacktrack(undoStart);

    compiler.generate(_body, writeEnd);

    compiler.bind(writeEnd);
    compiler.copyRegister(_endRegister, CURRENT_POSITION);
    compiler.pushBacktrack(undoEnd);
    compiler.goto(onSuccess);

    compiler.bind(undoStart);
    compiler.copyRegister(_startRegister, NO_POSITION_REGISTER);
    compiler.backtrack();

    compiler.bind(undoEnd);
    compiler.copyRegister(_endRegister, NO_POSITION_REGISTER);
    compiler.backtrack();
  }

  MiniExpAnalysis analyze(MiniExpCompiler compiler) {
    allocateRegisters(compiler);
    MiniExpAnalysis bodyAnalysis = _body.analyze(compiler);
    return new MiniExpAnalysis.capture(
        bodyAnalysis, _startRegister, _endRegister);
  }
}

class MiniExpMatch implements Match {
  final Pattern pattern;
  final String input;
  final List<int> _registers;
  final int _firstCaptureReg;

  MiniExpMatch(
      this.pattern, this.input, this._registers, this._firstCaptureReg);

  int get groupCount => (_registers.length - 2 - _firstCaptureReg) >> 1;

  int get start => _registers[_firstCaptureReg];

  int get end => _registers[_firstCaptureReg + 1];

  String group(index) {
    if (index > groupCount) {
      throw new RangeError("Invalid regexp group number");
    }
    index *= 2;
    index += _firstCaptureReg;
    if (_registers[index] == NO_POSITION) return null;
    return input.substring(_registers[index], _registers[index + 1]);
  }

  List<String> groups(List<int> groupIndices) {
    List<String> answer = new List<String>();
    for (int i in groupIndices) {
      answer.add(group(i));
    }
    return answer;
  }

  String operator[](index) => group(index);
}

class _MiniExp implements RegExp {
  List<int> _byteCodes;
  List<int> _initialRegisterValues;
  int _firstCaptureRegister;
  int _stickyEntryPoint;
  String _constantPool;
  final String pattern;
  final bool isMultiLine;
  final bool isCaseSensitive;

  _MiniExp(this.pattern, this.isMultiLine, this.isCaseSensitive) {
    var compiler = new MiniExpCompiler(pattern, isCaseSensitive);
    var parser = new MiniExpParser(compiler, pattern, isMultiLine);
    MiniExpAst ast = parser.parse();
    _generateCode(compiler, ast, pattern);
  }

  Match matchAsPrefix(String a, [int a1 = 0]) {
    return _match(a, a1, _stickyEntryPoint);
  }

  Match firstMatch(String a) => _match(a, 0, 0);

  bool hasMatch(String a) => _match(a, 0, 0) != null;

  String stringMatch(String a) {
    Match m = _match(a, 0, 0);
    if (m == null) return null;
    return m[0];
  }

  Iterable<Match> allMatches(String a, [int start = 0]) {
    if (start < 0 || start > a.length) {
      throw new RangeError("Start index out of range");
    }
    List<Match> answer = new List<Match>();
    Match m;
    while (start <= a.length && (m = _match(a, start, 0)) != null) {
      if (m.start == m.end) {
        start = m.end + 1;
      } else {
        start = m.end;
      }
      answer.add(m);
    }
    return answer;
  }

  Match _match(String a, int startPosition, int startProgramCounter) {
    List<int> registers =
        new List<int>.from(_initialRegisterValues, growable: false);
    var interpreter =
        new MiniExpInterpreter(_byteCodes, _constantPool, registers);
    if (!interpreter.interpret(a, startPosition, startProgramCounter)) {
      return null;
    }
    return new MiniExpMatch(this, a, registers, _firstCaptureRegister);
  }

  void _generateCode(MiniExpCompiler compiler, MiniExpAst ast, String source) {
    // Top level capture regs.
    int topLevelCaptureReg = compiler.allocateCaptureRegisters();

    MiniExpAnalysis topAnalysis = ast.analyze(compiler);

    compiler.addCaptureRegisters();

    var stickyEntryPoint = new MiniExpLabel();
    var stickyStart = new MiniExpLabel();
    var failSticky = new MiniExpLabel();

    var start = new MiniExpLabel();
    compiler.bind(start);

    var fail = new MiniExpLabel();
    compiler.pushBacktrack(fail);

    compiler.bind(stickyStart);
    compiler.copyRegister(topLevelCaptureReg, CURRENT_POSITION);

    var succeed = new MiniExpLabel();
    compiler.generate(ast, succeed);

    compiler.bind(fail);
    if (!topAnalysis.anchored) {
      var end = new MiniExpLabel();
      compiler.gotoIfGreaterEqual(CURRENT_POSITION, STRING_LENGTH, end);
      compiler.addToRegister(CURRENT_POSITION, 1);
      compiler.goto(start);
      compiler.bind(end);
    }
    compiler.bind(failSticky);
    compiler.fail();

    compiler.bind(succeed);
    compiler.copyRegister(topLevelCaptureReg - 1, CURRENT_POSITION);
    compiler.succeed();

    compiler.bind(stickyEntryPoint);
    compiler.pushBacktrack(failSticky);
    compiler.goto(stickyStart);

    _byteCodes = compiler.codes;
    _constantPool = compiler.constantPool;
    _initialRegisterValues = compiler.registers;
    _firstCaptureRegister = compiler.firstCaptureRegister;
    _stickyEntryPoint = stickyEntryPoint.location;
  }
}

// Lexer tokens.
enum Token {
  none,
  quant,
  backslash,
  dot,
  lParen,
  rParen,
  lSquare,
  hat,
  dollar,
  pipe,
  backReference,
  wordBoundary,
  notWordBoundary,
  wordCharacter,
  notWordCharacter,
  digit,
  notDigit,
  whitespace,
  notWhitespace,
  nonCapturing,
  lookAhead,
  negativeLookAhead,
  other
}

class MiniExpParser {
  // The constant pool is used to look up character data when the regexp is
  // running.  It consists of the regexp source with some characters appended
  // to handle escapes that are not literally present in the regexp input.
  final MiniExpCompiler _compiler;
  final String _source;
  final bool _isMultiLine;

  int _captureCount = 0;
  String _constantPool;

  // State of the parser and lexer.
  int _position = 0;  // Location in source.
  Token _lastToken;
  // This is the offset in the constant pool of the character data associated
  // with the token.
  int _lastTokenIndex;
  // Greedyness of the last single-character quantifier.
  bool _lastWasGreedy;
  int _lastBackReferenceIndex;
  int _minimumRepeats;
  int _maximumRepeats;

  MiniExpParser(this._compiler, this._source, this._isMultiLine);

  MiniExpAst parse() {
    getToken();
    MiniExpAst ast = parseDisjunction();
    expectToken(Token.none);
    return ast;
  }

  int _at(int _position) => _source.codeUnitAt(_position);

  bool _has(int _position) => _source.length > _position;

  void error(String message) {
    throw new FormatException(
        "Error while parsing regexp: ${message}", _source, _position);
  }

  MiniExpAst parseDisjunction() {
    MiniExpAst ast = parseAlternative();
    while (acceptToken(Token.pipe)) {
      ast = new Disjunction(ast, parseAlternative());
    }
    return ast;
  }

  bool endOfAlternative() {
    return _lastToken == Token.pipe || _lastToken == Token.rParen ||
        _lastToken == Token.none;
  }

  MiniExpAst parseAlternative() {
    if (endOfAlternative()) {
      return new EmptyAlternative();
    }
    MiniExpAst ast = parseTerm();
    while (!endOfAlternative()) {
      ast = new Alternative(ast, parseTerm());
    }
    return ast;
  }

  MiniExpAst tryParseAssertion() {
    if (acceptToken(Token.hat)) {
      return _isMultiLine ? new AtBeginningOfLine() : new AtStart();
    }
    if (acceptToken(Token.dollar)) {
      return _isMultiLine ? new AtEndOfLine() : new AtEnd();
    }
    if (acceptToken(Token.wordBoundary)) return new WordBoundary(true);
    if (acceptToken(Token.notWordBoundary)) return new WordBoundary(false);
    if (acceptToken(Token.lookAhead)) {
      var ast = new LookAhead(true, parseDisjunction(), _compiler);
      expectToken(Token.rParen);
      return ast;
    }
    if (acceptToken(Token.negativeLookAhead)) {
      var ast = new LookAhead(false, parseDisjunction(), _compiler);
      expectToken(Token.rParen);
      return ast;
    }
    return null;
  }

  MiniExpAst parseTerm() {
    MiniExpAst ast = tryParseAssertion();
    if (ast == null) {
      ast = parseAtom();
      if (peekToken(Token.quant)) {
        MiniExpAst quant = new Quantifier(
            _minimumRepeats, _maximumRepeats, _lastWasGreedy, ast, _compiler);
        expectToken(Token.quant);
        return quant;
      }
    }
    return ast;
  }

  MiniExpAst parseAtom() {
    if (peekToken(Token.other)) {
      MiniExpAst result = new Atom(_lastTokenIndex);
      expectToken(Token.other);
      return result;
    }
    if (acceptToken(Token.dot)) {
      CharClass ast = new CharClass(false);  // Negative char class.
      ast.add(CHAR_CODE_NEWLINE, CHAR_CODE_NEWLINE);
      ast.add(CHAR_CODE_CARRIAGE_RETURN, CHAR_CODE_CARRIAGE_RETURN);
      ast.add(CHAR_CODE_LINE_SEPARATOR, CHAR_CODE_PARAGRAPH_SEPARATOR);
      return ast;
    }

    if (peekToken(Token.backReference)) {
      MiniExpAst backRef = new BackReference(_lastBackReferenceIndex);
      expectToken(Token.backReference);
      return backRef;
    }

    if (acceptToken(Token.lParen)) {
      MiniExpAst ast = parseDisjunction();
      ast = new Capture(_captureCount++, ast);
      expectToken(Token.rParen);
      return ast;
    }
    if (acceptToken(Token.nonCapturing)) {
      MiniExpAst ast = parseDisjunction();
      expectToken(Token.rParen);
      return ast;
    }

    CharClass charClass;
    bool digitCharClass = false;
    if (acceptToken(Token.wordCharacter)) {
      charClass = new CharClass(true);
    } else if (acceptToken(Token.notWordCharacter)) {
      charClass = new CharClass(false);
    } else if (acceptToken(Token.digit)) {
      charClass = new CharClass(true);
      digitCharClass = true;
    } else if (acceptToken(Token.notDigit)) {
      charClass = new CharClass(false);
      digitCharClass = true;
    }
    if (charClass != null) {
      charClass.add(CHAR_CODE_0, CHAR_CODE_9);
      if (!digitCharClass) {
        charClass.add(CHAR_CODE_UPPER_A, CHAR_CODE_UPPER_Z);
        charClass.add(CHAR_CODE_UNDERSCORE, CHAR_CODE_UNDERSCORE);
        charClass.add(CHAR_CODE_LOWER_A, CHAR_CODE_LOWER_Z);
      }
      return charClass;
    }

    if (acceptToken(Token.whitespace)) {
      charClass = new CharClass(true);
    } else if (acceptToken(Token.notWhitespace)) {
      charClass = new CharClass(false);
    }
    if (charClass != null) {
      charClass.addSpaces();
      return charClass;
    }
    if (peekToken(Token.lSquare)) {
      return parseCharacterClass();
    }
    if (peekToken(Token.none)) error("Unexpected end of regexp");
    error("Unexpected token $_lastToken");
    return null;
  }

  MiniExpAst parseCharacterClass() {
    CharClass charClass;
    if (_has(_position) && _at(_position) == CHAR_CODE_CARET) {
      _position++;
      charClass = new CharClass(false);
    } else {
      charClass = new CharClass(true);
    }
    while (_has(_position)) {
      int code = _at(_position);
      if (code == CHAR_CODE_R_SQUARE) {
        // End of character class.  This reads the terminating square bracket.
        getToken();
        break;
      }
      // Single character or escape code representing a single character.
      code = _readCharacterClassCode();
      // If code is -1 then we found an escape code representing several
      // characters.
      if (code == -1) {
        if (!_has(_position + 1)) error("Unexpected end of regexp");
        int code2 = _at(_position + 1);
        charClass.addSpecial(code2);
        _position += 2;
        // These escape codes can't be part of a range, so move on.
        continue;
      }
      if (!_has(_position) || _at(_position) != CHAR_CODE_DASH) {
        // No dash here, so it's not part of a range.  Add the code and
        // move on.
        charClass.add(code, code);
        continue;
      }
      _position++;
      if (!_has(_position)) error("Unexpected end of regexp");
      int rawCode = _at(_position);
      int code3 = -1;
      if (rawCode != CHAR_CODE_R_SQUARE) {
        code3 = _readCharacterClassCode();
      }
      // If we hit a raw right square or an escape that represents more than
      // a single character then the dash is not to be interpreted as part of
      // a range. Output the single character and the dash separately, and move
      // on.
      if (rawCode == CHAR_CODE_R_SQUARE || code3 == -1) {
        charClass.add(code, code);
        charClass.add(CHAR_CODE_DASH, CHAR_CODE_DASH);
        continue;
      }
      // Found a range.
      if (code > code3) error("Character range out of order");
      charClass.add(code, code3);
    }
    expectToken(Token.other);  // The terminating right square bracket.
    return charClass;
  }

  int _readCharacterClassCode() {
    int code = _at(_position);
    if (code != CHAR_CODE_BACKSLASH) {
      _position++;
      return code;
    }
    if (!_has(_position + 1)) error("Unexpected end of regexp");
    int code2 = _at(_position + 1);
    int lower = (code2 | 0x20);
    if (lower == CHAR_CODE_LOWER_D || lower == CHAR_CODE_LOWER_S ||
        lower == CHAR_CODE_LOWER_W) {
      return -1;
    }
    if (CHAR_CODE_0 <= code2 && code2 <= CHAR_CODE_9) {
      _position++;
      code = lexInteger();
      return code;
    }
    _position += 2;
    if (code2 == CHAR_CODE_LOWER_U) {
      code = lexHex(4);
    } else if (code2 == CHAR_CODE_LOWER_X) {
      code = lexHex(2);
    } else if (CONTROL_CHARACTERS.containsKey(code2)) {
      code = CONTROL_CHARACTERS[code2];
    } else {
      code = code2;
    }
    // In the case of a malformed escape we just interpret as if the backslash
    // was not there.
    if (code == -1) code = code2;
    return code;
  }

  void expectToken(Token token) {
    if (token != _lastToken) {
      error("At _position ${_position - 1} expected $token, "
            "found $_lastToken");
    }
    getToken();
  }

  bool acceptToken(Token token) {
    if (token == _lastToken) {
      getToken();
      return true;
    }
    return false;
  }

  bool peekToken(Token token) => token == _lastToken;

  static const CHARCODE_TO_TOKEN = const <Token>[
    Token.other, Token.other, Token.other, Token.other,    // 0-3
    Token.other, Token.other, Token.other, Token.other,    // 4-7
    Token.other, Token.other, Token.other, Token.other,    // 8-11
    Token.other, Token.other, Token.other, Token.other,    // 12-15
    Token.other, Token.other, Token.other, Token.other,    // 16-19
    Token.other, Token.other, Token.other, Token.other,    // 20-23
    Token.other, Token.other, Token.other, Token.other,    // 24-27
    Token.other, Token.other, Token.other, Token.other,    // 28-31
    Token.other, Token.other, Token.other, Token.other,    //  !"#
    Token.dollar, Token.other, Token.other, Token.other,   // $%&'
    Token.lParen, Token.rParen, Token.quant, Token.quant,  // ()*+,
    Token.other, Token.other, Token.dot, Token.other,      // ,-./
    Token.other, Token.other, Token.other, Token.other,    // 0123
    Token.other, Token.other, Token.other, Token.other,    // 4567
    Token.other, Token.other, Token.other, Token.other,    // 89:;
    Token.other, Token.other, Token.other, Token.quant,    // <=>?
    Token.other, Token.other, Token.other, Token.other,    // @ABC
    Token.other, Token.other, Token.other, Token.other,    // DEFG
    Token.other, Token.other, Token.other, Token.other,    // HIJK
    Token.other, Token.other, Token.other, Token.other,    // LMNO
    Token.other, Token.other, Token.other, Token.other,    // PQRS
    Token.other, Token.other, Token.other, Token.other,    // TUVW
    Token.other, Token.other, Token.other, Token.lSquare,  // XYZ[
    Token.backslash, Token.other, Token.hat, Token.other,  // \]^_
    Token.other, Token.other, Token.other, Token.other,    // `abc
    Token.other, Token.other, Token.other, Token.other,    // defg
    Token.other, Token.other, Token.other, Token.other,    // hijk
    Token.other, Token.other, Token.other, Token.other,    // lmno
    Token.other, Token.other, Token.other, Token.other,    // pqrs
    Token.other, Token.other, Token.other, Token.other,    // tuvw
    Token.other, Token.other, Token.other, Token.quant,    // xyz{
    Token.pipe, Token.other];                              // |}

  static const ESCAPES = const {
    CHAR_CODE_LOWER_B: Token.wordBoundary,
    CHAR_CODE_UPPER_B: Token.notWordBoundary,
    CHAR_CODE_LOWER_W: Token.wordCharacter,
    CHAR_CODE_UPPER_W: Token.notWordCharacter,
    CHAR_CODE_LOWER_D: Token.digit,
    CHAR_CODE_UPPER_D: Token.notDigit,
    CHAR_CODE_LOWER_S: Token.whitespace,
    CHAR_CODE_UPPER_S: Token.notWhitespace
  };

  static const CONTROL_CHARACTERS = const {
    CHAR_CODE_0: CHAR_CODE_NUL,
    CHAR_CODE_LOWER_B: CHAR_CODE_BACKSPACE,
    CHAR_CODE_LOWER_F: CHAR_CODE_FORM_FEED,
    CHAR_CODE_LOWER_N: CHAR_CODE_NEWLINE,
    CHAR_CODE_LOWER_R: CHAR_CODE_CARRIAGE_RETURN,
    CHAR_CODE_LOWER_T: CHAR_CODE_TAB,
    CHAR_CODE_LOWER_V: CHAR_CODE_VERTICAL_TAB
  };

  static Token tokenFromCharcode(int code) {
    if (code >= CHARCODE_TO_TOKEN.length) return Token.other;
    return CHARCODE_TO_TOKEN[code];
  }

  bool onDigit(int _position) {
    if (!_has(_position)) return false;
    if (_at(_position) < CHAR_CODE_0) return false;
    return _at(_position) <= CHAR_CODE_9;
  }

  void getToken() {
    if (!_has(_position)) {
      _lastToken = Token.none;
      return;
    }
    _lastTokenIndex = _position;
    int code = _at(_position);
    Token token = _lastToken = tokenFromCharcode(code);
    if (token == Token.backslash) {
      lexBackslash();
      return;
    }
    if (token == Token.lParen) {
      lexLeftParenthesis();
    } else if (token == Token.quant) {
      lexQuantifier();
    }
    _position++;
  }

  void lexBackslash() {
    if (!_has(_position + 1)) error("\\ at end of pattern");
    int nextCode = _at(_position + 1);
    if (ESCAPES.containsKey(nextCode)) {
      _position += 2;
      _lastToken = ESCAPES[nextCode];
    } else if (CONTROL_CHARACTERS.containsKey(nextCode)) {
      _position += 2;
      _lastToken = Token.other;
      _lastTokenIndex = _source.length +
          _compiler.addToConstantPool(CONTROL_CHARACTERS[nextCode]);
    } else if (onDigit(_position + 1)) {
      _position++;
      _lastBackReferenceIndex = lexInteger();
      _lastToken = Token.backReference;
    } else if (nextCode == CHAR_CODE_LOWER_X || nextCode == CHAR_CODE_LOWER_U) {
      _position += 2;
      _lastToken = Token.other;
      int codeUnit = lexHex(nextCode == CHAR_CODE_LOWER_X ? 2 : 4);
      if (codeUnit == -1) {
        _lastTokenIndex = _position - 1;
      } else {
        _lastTokenIndex =
            _source.length + _compiler.addToConstantPool(codeUnit);
      }
    } else {
      _lastToken = Token.other;
      _lastTokenIndex = _position + 1;
      _position += 2;
    }
  }

  int lexHex(int chars) {
    if (!_has(_position + chars - 1)) return -1;
    int total = 0;
    for (var i = 0; i < chars; i++) {
      total *= 16;
      int charCode = _at(_position + i);
      if (charCode >= CHAR_CODE_0 && charCode <= CHAR_CODE_9) {
        total += charCode - CHAR_CODE_0;
      } else if (charCode >= CHAR_CODE_UPPER_A &&
                 charCode <= CHAR_CODE_UPPER_F) {
        total += 10 + charCode - CHAR_CODE_UPPER_A;
      } else if (charCode >= CHAR_CODE_LOWER_A &&
                 charCode <= CHAR_CODE_LOWER_F) {
        total += 10 + charCode - CHAR_CODE_LOWER_A;
      } else {
        return -1;
      }
    }
    _position += chars;
    return total;
  }

  int lexInteger() {
    int total = 0;
    while (true) {
      if (!_has(_position)) return total;
      int code = _at(_position);
      if (code >= CHAR_CODE_0 && code <= CHAR_CODE_9) {
        _position++;
        total *= 10;
        total += code - CHAR_CODE_0;
      } else {
        return total;
      }
    }
  }

  void lexLeftParenthesis() {
    if (!_has(_position + 1)) error("unterminated group");
    if (_at(_position + 1) == CHAR_CODE_QUERY) {
      if (!_has(_position + 2)) error("unterminated group");
      int parenthesisModifier = _at(_position + 2);
      if (parenthesisModifier == CHAR_CODE_EQUALS) {
        _lastToken = Token.lookAhead;
      } else if (parenthesisModifier == CHAR_CODE_COLON) {
        _lastToken = Token.nonCapturing;
      } else if (parenthesisModifier == CHAR_CODE_BANG) {
        _lastToken = Token.negativeLookAhead;
      } else {
        error("invalid group");
      }
      _position += 2;
      return;
    }
  }

  void lexQuantifier() {
    int quantifierCode = _at(_position);
    if (quantifierCode == CHAR_CODE_L_BRACE) {
      bool parsedRepeats = false;
      int savedPosition = _position;
      if (onDigit(_position + 1)) {
        _position++;
        // We parse the repeats in the lexer.  Forms allowed are {n}, {n,}
        // and {n,m}.
        _minimumRepeats = lexInteger();
        if (_has(_position)) {
          if (_at(_position) == CHAR_CODE_R_BRACE) {
            _maximumRepeats = _minimumRepeats;
            parsedRepeats = true;
          } else if (_at(_position) == CHAR_CODE_COMMA) {
            _position++;
            if (_has(_position)) {
              if (_at(_position) == CHAR_CODE_R_BRACE) {
                _maximumRepeats = null;  // No maximum.
                parsedRepeats = true;
              } else if (onDigit(_position)) {
                _maximumRepeats = lexInteger();
                if (_has(_position) &&
                    _at(_position) == CHAR_CODE_R_BRACE) {
                  parsedRepeats = true;
                }
              }
            }
          }
        }
      }
      if (parsedRepeats) {
        if (_maximumRepeats != null && _minimumRepeats > _maximumRepeats) {
          error("numbers out of order in {} quantifier");
        }
      } else {
        // If parsing of the repeats fails then we follow JS in interpreting
        // the left brace as a literal.
        _position = savedPosition;
        _lastToken = Token.other;
        return;
      }
    } else if (quantifierCode == CHAR_CODE_ASTERISK) {
      _minimumRepeats = 0;
      _maximumRepeats = null;  // No maximum.
    } else if (quantifierCode == CHAR_CODE_PLUS) {
      _minimumRepeats = 1;
      _maximumRepeats = null;  // No maximum.
    } else {
      _minimumRepeats = 0;
      _maximumRepeats = 1;
    }
    if (_has(_position + 1) &&
        _at(_position + 1) == CHAR_CODE_QUERY) {
      _position++;
      _lastWasGreedy = false;
    } else {
      _lastWasGreedy = true;
    }
  }
}

void disassemble(List<int> codes) {
  print("\nDisassembly\n");
  var labels = new List<bool>(codes.length);
  for (var i = 0; i < codes.length; ) {
    int code = codes[i];
    if (code == PUSH_BACKTRACK || code == GOTO) {
      int pushed = codes[i + 1];
      if (pushed >= 0 && pushed < codes.length) labels[pushed] = true;
    }
    i += BYTE_CODE_NAMES[code * 3 + 1] + BYTE_CODE_NAMES[code * 3 + 2] + 1;
  }
  for (var i = 0; i < codes.length; ) {
    if (labels[i]) print("${i}:");
    i += disassembleSingleInstruction(codes, i, null);
  }
  print("\nEnd Disassembly\n");
}

int disassembleSingleInstruction(List<int> codes, int i, List<int> registers) {
    int code = codes[i];
    int regs = BYTE_CODE_NAMES[code * 3 + 1];
    int otherArgs = BYTE_CODE_NAMES[code * 3 + 2];
    String line = "${i}: ${BYTE_CODE_NAMES[code * 3]}";
    for (int j = 0; j < regs; j++) {
      int reg = codes[i + 1 + j];
      line = "${line} ${REGISTER_NAMES[reg]}";
      if (registers != null) line = "${line}:${registers[reg]}";
    }
    for (int j = 0; j < otherArgs; j++) {
      line = line + " " + codes[i + 1 + regs + j].toString();
    }
    print(line);
    return regs + otherArgs + 1;
}

class MiniExpInterpreter {
  final List<int> _byteCodes;
  final String _constantPool;
  final List<int> _registers;

  MiniExpInterpreter(this._byteCodes, this._constantPool, this._registers);

  List<int> stack = new List<int>();
  int stackPointer = 0;

  bool interpret(String _subject, int startPosition, int programCounter) {
    _registers[STRING_LENGTH] = _subject.length;
    _registers[CURRENT_POSITION] = startPosition;
    while (true) {
      int byteCode = _byteCodes[programCounter];
      programCounter++;
      switch (byteCode) {
        case GOTO:
          programCounter = _byteCodes[programCounter];
          break;
        case PUSH_REGISTER:
          int reg = _registers[_byteCodes[programCounter++]];
          if (stackPointer == stack.length) {
            stack.add(reg);
            stackPointer++;
          } else {
            stack[stackPointer++] = reg;
          }
          break;
        case PUSH_BACKTRACK:
          int value = _byteCodes[programCounter++];
          if (stackPointer == stack.length) {
            stack.add(value);
            stackPointer++;
          } else {
            stack[stackPointer++] = value;
          }
          int position = _registers[CURRENT_POSITION];
          if (stackPointer == stack.length) {
            stack.add(position);
            stackPointer++;
          } else {
            stack[stackPointer++] = position;
          }
          break;
        case POP_REGISTER:
          _registers[_byteCodes[programCounter++]] = stack[--stackPointer];
          break;
        case BACKTRACK_EQ:
          int reg1 = _registers[_byteCodes[programCounter++]];
          int reg2 = _registers[_byteCodes[programCounter++]];
          if (reg1 == reg2) {
            _registers[CURRENT_POSITION] = stack[--stackPointer];
            programCounter = stack[--stackPointer];
          }
          break;
        case BACKTRACK_NE:
          int reg1 = _registers[_byteCodes[programCounter++]];
          int reg2 = _registers[_byteCodes[programCounter++]];
          if (reg1 != reg2) {
            _registers[CURRENT_POSITION] = stack[--stackPointer];
            programCounter = stack[--stackPointer];
          }
          break;
        case BACKTRACK_GT:
          int reg1 = _registers[_byteCodes[programCounter++]];
          int reg2 = _registers[_byteCodes[programCounter++]];
          if (reg1 > reg2) {
            _registers[CURRENT_POSITION] = stack[--stackPointer];
            programCounter = stack[--stackPointer];
          }
          break;
        case BACKTRACK_IF_NO_MATCH:
          if (_subject.codeUnitAt(_registers[CURRENT_POSITION]) !=
              _constantPool.codeUnitAt(_byteCodes[programCounter++])) {
            _registers[CURRENT_POSITION] = stack[--stackPointer];
            programCounter = stack[--stackPointer];
          }
          break;
        case BACKTRACK_IF_IN_RANGE:
          int code = _subject.codeUnitAt(_registers[CURRENT_POSITION]);
          int from = _byteCodes[programCounter++];
          int to = _byteCodes[programCounter++];
          if (from <= code && code <= to) {
            _registers[CURRENT_POSITION] = stack[--stackPointer];
            programCounter = stack[--stackPointer];
          }
          break;
        case GOTO_IF_MATCH:
          int code = _subject.codeUnitAt(_registers[CURRENT_POSITION]);
          int expected = _byteCodes[programCounter++];
          int dest = _byteCodes[programCounter++];
          if (code == expected) programCounter = dest;
          break;
        case GOTO_IF_IN_RANGE:
          int code = _subject.codeUnitAt(_registers[CURRENT_POSITION]);
          int from = _byteCodes[programCounter++];
          int to = _byteCodes[programCounter++];
          int dest = _byteCodes[programCounter++];
          if (from <= code && code <= to) programCounter = dest;
          break;
        case GOTO_EQ:
          int reg1 = _registers[_byteCodes[programCounter++]];
          int reg2 = _registers[_byteCodes[programCounter++]];
          int dest = _byteCodes[programCounter++];
          if (reg1 == reg2) programCounter = dest;
          break;
        case GOTO_GE:
          int reg1 = _registers[_byteCodes[programCounter++]];
          int reg2 = _registers[_byteCodes[programCounter++]];
          int dest = _byteCodes[programCounter++];
          if (reg1 >= reg2) programCounter = dest;
          break;
        case GOTO_IF_WORD_CHARACTER:
          int offset = _byteCodes[programCounter++];
          int charCode =
              _subject.codeUnitAt(_registers[CURRENT_POSITION] + offset);
          int dest = _byteCodes[programCounter++];
          if (charCode >= CHAR_CODE_0) {
            if (charCode <= CHAR_CODE_9) {
              programCounter = dest;
            } else if (charCode >= CHAR_CODE_UPPER_A) {
              if (charCode <= CHAR_CODE_UPPER_Z) {
                programCounter = dest;
              } else if (charCode == CHAR_CODE_UNDERSCORE) {
                programCounter = dest;
              } else if (charCode >= CHAR_CODE_LOWER_A &&
                         charCode <= CHAR_CODE_LOWER_Z) {
                programCounter = dest;
              }
            }
          }
          break;
        case ADD_TO_REGISTER:
          int registerIndex = _byteCodes[programCounter++];
          _registers[registerIndex] += _byteCodes[programCounter++];
          break;
        case COPY_REGISTER:
          // We don't normally keep the stack pointer in sync with its slot in
          // the _registers, but we have to have it in sync here.
          _registers[STACK_POINTER] = stackPointer;
          int registerIndex = _byteCodes[programCounter++];
          int value = _registers[_byteCodes[programCounter++]];
          _registers[registerIndex] = value;
          stackPointer = _registers[STACK_POINTER];
          break;
        case BACKTRACK:
          _registers[CURRENT_POSITION] = stack[--stackPointer];
          programCounter = stack[--stackPointer];
          break;
        case SUCCEED:
          return true;
        case FAIL:
          return false;
        default:
          assert(false);
          break;
      }
    }
  }
}
