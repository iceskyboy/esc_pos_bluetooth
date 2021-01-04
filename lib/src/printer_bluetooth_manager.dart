/*
 * esc_pos_bluetooth
 * Created by Andrey Ushakov
 * 
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import '../esc_pos_bluetooth.dart';
import './enums.dart';
import 'package:image/image.dart';

/// Bluetooth printer
class PrinterBluetooth {
  PrinterBluetooth(this.device);
  final BluetoothDevice device;

  // String get name => device.name;
  // String get address => device.address;
  // int get type => device.type;
  // bool get connected => device.connected;
}

/// Printer Bluetooth Manager
class PrinterBluetoothManager {

  void setGenerator(PaperSize paperSize, CapabilityProfile profile, {int spaceBetweenRows = 5}) {
    _generator =
        Generator(paperSize, profile, spaceBetweenRows: spaceBetweenRows);
  }

  Generator _generator;

  BluetoothManager bluetoothManager = BluetoothManager.instance;
  Future<bool> get isConnected => bluetoothManager.isConnected;
  Stream<int> get state => bluetoothManager.state;

  // bool _isConnected = false;
  StreamSubscription _scanResultsSubscription;
  StreamSubscription _isScanningSubscription;
  PrinterBluetooth _selectedPrinter;

  final BehaviorSubject<bool> _isScanning = BehaviorSubject.seeded(false);
  Stream<bool> get isScanningStream => _isScanning.stream;

  final BehaviorSubject<List<PrinterBluetooth>> _scanResults =
      BehaviorSubject.seeded([]);
  Stream<List<PrinterBluetooth>> get scanResults => _scanResults.stream;

  Future startScan(Duration timeout) async {
    _scanResults.add(<PrinterBluetooth>[]);
    _scanResultsSubscription = bluetoothManager.scanResults.listen((devices) {
      _scanResults.add(devices.map((d) => PrinterBluetooth(d)).toList());
    });

    _isScanningSubscription =
        bluetoothManager.isScanning.listen((isScanningCurrent) async {
      // If isScanning value changed (scan just stopped)
      if (_isScanning.value && !isScanningCurrent) {
        _scanResultsSubscription.cancel();
        _isScanningSubscription.cancel();
      }
      _isScanning.add(isScanningCurrent);
    });

    await bluetoothManager.startScan(timeout: timeout).catchError((e) {
      throw new Exception(e.message);
    });

  }

  void stopScan() async {
    await bluetoothManager.stopScan();
  }

  Future<bool> connectPrinter(PrinterBluetooth printer) async {
    // await _bluetoothManager.disconnect();
    _selectedPrinter = printer;

    // Connect
    await bluetoothManager.connect(_selectedPrinter.device);
    // _isConnected = await _bluetoothManager.isConnected;
    writeBytes(_generator.reset());
    await Future.delayed(Duration(milliseconds: 500));

    return await bluetoothManager.isConnected;
  }

  Future<bool> disconnectPrinter() async {
    await bluetoothManager.disconnect();
    await Future.delayed(Duration(milliseconds: 500));
    return await bluetoothManager.isConnected;
  }

  Future<PosPrintResult> writeBytes(
    List<int> bytes, {
    int chunkSizeBytes = 20,
    int queueSleepTimeMs = 20,
  }) async {
    final Completer<PosPrintResult> completer = Completer();

    if (_selectedPrinter == null) {
      return Future<PosPrintResult>.value(PosPrintResult.printerNotSelected);
    } else if (_isScanning.value) {
      return Future<PosPrintResult>.value(PosPrintResult.scanInProgress);
    }

    // We have to rescan before connecting, otherwise we can connect only once
    // await _bluetoothManager.startScan(timeout: Duration(seconds: 5));
    // await _bluetoothManager.stopScan();

    // Subscribe to the events
    // _bluetoothManager.state.listen((state) async {
    //   print('_bluetoothManager state -> ${state.toString()}');
    //   switch (state) {
    //     case BluetoothManager.CONNECTED:
    //       break;
    //     case BluetoothManager.DISCONNECTED:
    //       // _isConnected = false;
    //       break;
    //     default:
    //       break;
    //   }
    // });

    /*final len = bytes.length;
    List<List<int>> chunks = [];
    for (var i = 0; i < len; i += chunkSizeBytes) {
      var end = (i + chunkSizeBytes < len) ? i + chunkSizeBytes : len;
      chunks.add(bytes.sublist(i, end));
    }

    for (var i = 0; i < chunks.length; i += 1) {
      await bluetoothManager.writeData(chunks[i]);
      sleep(Duration(milliseconds: queueSleepTimeMs));
    }*/

    await bluetoothManager.writeData(bytes);
    sleep(Duration(milliseconds: queueSleepTimeMs));
    completer.complete(PosPrintResult.success);

    // Printing timeout
    Future<dynamic>.delayed(Duration(seconds: 5)).then((v) async {
      if (!completer.isCompleted) {
        completer.complete(PosPrintResult.timeout);
      }
    });

    return completer.future;
  }

  void text(
      String text, {
        PosStyles styles = const PosStyles(),
        int linesAfter = 0,
        bool containsChinese = false,
        int maxCharsPerLine,
      }) {
    writeBytes(_generator.text(text,
        styles: styles,
        linesAfter: linesAfter,
        containsChinese: containsChinese,
        maxCharsPerLine: maxCharsPerLine),
      chunkSizeBytes: 20,
      queueSleepTimeMs: 20
    );
  }

  void setGlobalCodeTable(String codeTable) {
    writeBytes(_generator.setGlobalCodeTable(codeTable));
  }

  void setGlobalFont(PosFontType font, {int maxCharsPerLine}) {
    writeBytes(_generator.setGlobalFont(font, maxCharsPerLine: maxCharsPerLine));
  }

  void setStyles(PosStyles styles, {bool isKanji = false}) {
    writeBytes(_generator.setStyles(styles, isKanji: isKanji));
  }

  void rawBytes(List<int> cmd, {bool isKanji = false}) {
    writeBytes(_generator.rawBytes(cmd, isKanji: isKanji));
  }

  void emptyLines(int n) {
    writeBytes(_generator.emptyLines(n));
  }

  void feed(int n) {
    writeBytes(_generator.feed(n));
  }

  void cut({PosCutMode mode = PosCutMode.full}) {
    writeBytes(_generator.cut(mode: mode));
  }

  void printCodeTable({String codeTable}) {
    writeBytes(_generator.printCodeTable(codeTable: codeTable));
  }

  void beep({int n = 3, PosBeepDuration duration = PosBeepDuration.beep450ms}) {
    writeBytes(_generator.beep(n: n, duration: duration));
  }

  void reverseFeed(int n) {
    writeBytes(_generator.reverseFeed(n));
  }

  void row(List<PosColumn> cols) {
    writeBytes(_generator.row(cols));
  }

  void image(Image imgSrc, {PosAlign align = PosAlign.center}) {
    writeBytes(_generator.image(imgSrc, align: align));
  }

  void imageRaster(
      Image image, {
        PosAlign align = PosAlign.center,
        bool highDensityHorizontal = true,
        bool highDensityVertical = true,
        PosImageFn imageFn = PosImageFn.bitImageRaster,
      }) {
    writeBytes(_generator.imageRaster(
      image,
      align: align,
      highDensityHorizontal: highDensityHorizontal,
      highDensityVertical: highDensityVertical,
      imageFn: imageFn,
    ));
  }

  void barcode(
      Barcode barcode, {
        int width,
        int height,
        BarcodeFont font,
        BarcodeText textPos = BarcodeText.below,
        PosAlign align = PosAlign.center,
      }) {
    writeBytes(_generator.barcode(
      barcode,
      width: width,
      height: height,
      font: font,
      textPos: textPos,
      align: align,
    ));
  }

  void qrcode(
      String text, {
        PosAlign align = PosAlign.center,
        QRSize size = QRSize.Size4,
        QRCorrection cor = QRCorrection.L,
      }) {
    writeBytes(_generator.qrcode(text, align: align, size: size, cor: cor));
  }

  void drawer({PosDrawer pin = PosDrawer.pin2}) {
    writeBytes(_generator.drawer(pin: pin));
  }

  void hr({String ch = '-', int len, int linesAfter = 0}) {
    writeBytes(_generator.hr(ch: ch, linesAfter: linesAfter));
  }

  void textEncoded(
      Uint8List textBytes, {
        PosStyles styles = const PosStyles(),
        int linesAfter = 0,
        int maxCharsPerLine,
      }) {
    writeBytes(_generator.textEncoded(
      textBytes,
      styles: styles,
      linesAfter: linesAfter,
      maxCharsPerLine: maxCharsPerLine,
    ));
  }

}
