// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:test/test.dart';

const fcmDartServiceStart = 'FcmDartService#start';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MockMethodChannel mockChannel;
  FirebaseMessaging firebaseMessaging;

  setUp(() {
    mockChannel = MockMethodChannel();
    when(mockChannel.invokeMethod<bool>(fcmDartServiceStart, any))
        .thenAnswer((_) => Future.value(true));
    firebaseMessaging = FirebaseMessaging.private(
        mockChannel, FakePlatform(operatingSystem: 'ios'));
  });

  test('requestNotificationPermissions on ios with default permissions', () {
    firebaseMessaging.requestNotificationPermissions();
    verify(mockChannel.invokeMethod<void>(
        'requestNotificationPermissions', <String, bool>{
      'sound': true,
      'badge': true,
      'alert': true,
      'provisional': false
    }));
  });

  test('requestNotificationPermissions on ios with custom permissions', () {
    firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: false, provisional: true));
    verify(mockChannel.invokeMethod<void>(
        'requestNotificationPermissions', <String, bool>{
      'sound': false,
      'badge': true,
      'alert': true,
      'provisional': true
    }));
  });

  test('requestNotificationPermissions on android', () {
    firebaseMessaging = FirebaseMessaging.private(
        mockChannel, FakePlatform(operatingSystem: 'android'));

    firebaseMessaging.requestNotificationPermissions();
    verifyZeroInteractions(mockChannel);
  });

  test('requestNotificationPermissions on android', () {
    firebaseMessaging = FirebaseMessaging.private(
        mockChannel, FakePlatform(operatingSystem: 'android'));

    firebaseMessaging.requestNotificationPermissions();
    verifyZeroInteractions(mockChannel);
  });

  test('configure', () {
    firebaseMessaging.configure();
    verify(mockChannel.setMethodCallHandler(any));
    verify(mockChannel.invokeMethod<void>('configure'));
  });

  test('incoming token', () async {
    firebaseMessaging.configure();
    final dynamic handler =
        verify(mockChannel.setMethodCallHandler(captureAny)).captured.single;
    final String token1 = 'I am a super secret token';
    final String token2 = 'I am the new token in town';
    Future<String> tokenFromStream = firebaseMessaging.onTokenRefresh.first;
    await handler(MethodCall('onToken', token1));

    expect(await tokenFromStream, token1);

    tokenFromStream = firebaseMessaging.onTokenRefresh.first;
    await handler(MethodCall('onToken', token2));

    expect(await tokenFromStream, token2);
  });

  test('incoming iOS settings', () async {
    firebaseMessaging.configure();
    final dynamic handler =
        verify(mockChannel.setMethodCallHandler(captureAny)).captured.single;
    IosNotificationSettings iosSettings = const IosNotificationSettings();

    Future<IosNotificationSettings> iosSettingsFromStream =
        firebaseMessaging.onIosSettingsRegistered.first;
    await handler(MethodCall('onIosSettingsRegistered', iosSettings.toMap()));
    expect((await iosSettingsFromStream).toMap(), iosSettings.toMap());

    iosSettings = const IosNotificationSettings(sound: false);
    iosSettingsFromStream = firebaseMessaging.onIosSettingsRegistered.first;
    await handler(MethodCall('onIosSettingsRegistered', iosSettings.toMap()));
    expect((await iosSettingsFromStream).toMap(), iosSettings.toMap());
  });

  test('incoming messages', () async {
    final Completer<dynamic> onMessage = Completer<dynamic>();
    final Completer<dynamic> onLaunch = Completer<dynamic>();
    final Completer<dynamic> onResume = Completer<dynamic>();

    firebaseMessaging.configure(
      onMessage: (dynamic m) async {
        onMessage.complete(m);
      },
      onLaunch: (dynamic m) async {
        onLaunch.complete(m);
      },
      onResume: (dynamic m) async {
        onResume.complete(m);
      },
      onBackgroundMessage: validOnBackgroundMessage,
    );
    final dynamic handler =
        verify(mockChannel.setMethodCallHandler(captureAny)).captured.single;

    final Map<String, dynamic> onMessageMessage = <String, dynamic>{};
    final Map<String, dynamic> onLaunchMessage = <String, dynamic>{};
    final Map<String, dynamic> onResumeMessage = <String, dynamic>{};

    await handler(MethodCall('onMessage', onMessageMessage));
    expect(await onMessage.future, onMessageMessage);
    expect(onLaunch.isCompleted, isFalse);
    expect(onResume.isCompleted, isFalse);

    await handler(MethodCall('onLaunch', onLaunchMessage));
    expect(await onLaunch.future, onLaunchMessage);
    expect(onResume.isCompleted, isFalse);

    await handler(MethodCall('onResume', onResumeMessage));
    expect(await onResume.future, onResumeMessage);
  });

  const String myTopic = 'Flutter';

  test('subscribe to topic', () async {
    await firebaseMessaging.subscribeToTopic(myTopic);
    verify(mockChannel.invokeMethod<void>('subscribeToTopic', myTopic));
  });

  test('unsubscribe from topic', () async {
    await firebaseMessaging.unsubscribeFromTopic(myTopic);
    verify(mockChannel.invokeMethod<void>('unsubscribeFromTopic', myTopic));
  });

  test('getToken', () {
    firebaseMessaging.getToken();
    verify(mockChannel.invokeMethod<String>('getToken'));
  });

  test('deleteInstanceID', () {
    firebaseMessaging.deleteInstanceID();
    verify(mockChannel.invokeMethod<bool>('deleteInstanceID'));
  });

  test('autoInitEnabled', () {
    firebaseMessaging.autoInitEnabled();
    verify(mockChannel.invokeMethod<bool>('autoInitEnabled'));
  });

  test('setAutoInitEnabled', () {
    // assert that we havent called the method yet
    verifyNever(firebaseMessaging.setAutoInitEnabled(true));

    firebaseMessaging.setAutoInitEnabled(true);

    verify(mockChannel.invokeMethod<void>('setAutoInitEnabled', true));

    // assert that enabled = false was not yet called
    verifyNever(firebaseMessaging.setAutoInitEnabled(false));

    firebaseMessaging.setAutoInitEnabled(false);

    verify(mockChannel.invokeMethod<void>('setAutoInitEnabled', false));
  });

  test('configure bad onBackgroundMessage iOS', () async {
    expect(
      firebaseMessaging.configure(
        onBackgroundMessage: (dynamic message) => Future<dynamic>.value(),
      ),
      throwsArgumentError,
    );
    // Even with the bad arg, configure still should have been called
    verify(mockChannel.invokeMethod("configure"));
  });

  test('configure bad onBackgroundMessage android', () async {
    final firebaseMessaging = FirebaseMessaging.private(
        mockChannel, FakePlatform(operatingSystem: 'android'));
    expect(
      firebaseMessaging.configure(
        onBackgroundMessage: (dynamic message) => Future<dynamic>.value(),
      ),
      throwsArgumentError,
    );
    // Even though there was an error, configure still should have been called.
    verify(mockChannel.invokeMethod("configure"));
  });

  test('configure onBackgroundMessage android', () async {
    final firebaseMessaging = FirebaseMessaging.private(
        mockChannel, FakePlatform(operatingSystem: 'android'));
    final result = await firebaseMessaging.configure(
        onBackgroundMessage: validOnBackgroundMessage);
    expect(result, isTrue);
    verify(mockChannel.invokeMethod<void>("configure"));
    verify(mockChannel.invokeMethod<bool>(fcmDartServiceStart, any));
  });

  test('configure onBackgroundMessage ios', () async {
    final result = await firebaseMessaging.configure(
        onBackgroundMessage: validOnBackgroundMessage);
    expect(result, isFalse);
    verify(mockChannel.invokeMethod("configure"));
    verifyNever(mockChannel.invokeMethod(fcmDartServiceStart, any));
  });
}

Future<dynamic> validOnBackgroundMessage(Map<String, dynamic> message) async {}

class MockMethodChannel extends Mock implements MethodChannel {}
