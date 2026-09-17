// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env.dart';

// **************************************************************************
// EnviedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// generated_from: .env
final class _Env {
  static const List<int> _enviedkeylastFmApiKey = <int>[
    170114750,
    2459334803,
  ];

  static const List<int> _envieddatalastFmApiKey = <int>[
    170114716,
    2459334833,
  ];

  static final String lastFmApiKey = String.fromCharCodes(List<int>.generate(
    _envieddatalastFmApiKey.length,
    (int i) => i,
    growable: false,
  ).map((int i) => _envieddatalastFmApiKey[i] ^ _enviedkeylastFmApiKey[i]));

  static const List<int> _enviedkeylastFmApiSecret = <int>[
    1265939773,
    1531851884,
  ];

  static const List<int> _envieddatalastFmApiSecret = <int>[
    1265939743,
    1531851854,
  ];

  static final String lastFmApiSecret = String.fromCharCodes(List<int>.generate(
    _envieddatalastFmApiSecret.length,
    (int i) => i,
    growable: false,
  ).map(
      (int i) => _envieddatalastFmApiSecret[i] ^ _enviedkeylastFmApiSecret[i]));

  static final int _enviedkey_hideDonations = 3442485226;

  static final int _hideDonations = _enviedkey_hideDonations ^ 3442485226;

  static const List<int> _enviedkey_enableUpdateChecker = <int>[776224945];

  static const List<int> _envieddata_enableUpdateChecker = <int>[776224896];

  static final String _enableUpdateChecker = String.fromCharCodes(
      List<int>.generate(
    _envieddata_enableUpdateChecker.length,
    (int i) => i,
    growable: false,
  ).map((int i) =>
          _envieddata_enableUpdateChecker[i] ^
          _enviedkey_enableUpdateChecker[i]));

  static const List<int> _enviedkey_releaseChannel = <int>[
    3329921787,
    3497720787,
    980246697,
    1263046962,
    992983724,
    3292077623,
    2008151605,
  ];

  static const List<int> _envieddata_releaseChannel = <int>[
    3329921685,
    3497720762,
    980246734,
    1263047002,
    992983768,
    3292077659,
    2008151628,
  ];

  static final String _releaseChannel = String.fromCharCodes(List<int>.generate(
    _envieddata_releaseChannel.length,
    (int i) => i,
    growable: false,
  ).map(
      (int i) => _envieddata_releaseChannel[i] ^ _enviedkey_releaseChannel[i]));
}
