// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'detector_painters.dart';

class PictureScanner extends StatefulWidget {
  const PictureScanner({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PictureScannerState();
}

class _PictureScannerState extends State<PictureScanner> {
  File? _imageFile;
  Size? _imageSize;
  dynamic _scanResults;
  Detector _currentDetector = Detector.text;
  final BarcodeDetector _barcodeDetector =
      FirebaseVision.instance.barcodeDetector();
  final FaceDetector _faceDetector = FirebaseVision.instance.faceDetector();
  final ImageLabeler _imageLabeler = FirebaseVision.instance.imageLabeler();
  final ImageLabeler _cloudImageLabeler =
      FirebaseVision.instance.cloudImageLabeler();
  final TextRecognizer _recognizer = FirebaseVision.instance.textRecognizer();
  final TextRecognizer _cloudRecognizer =
      FirebaseVision.instance.cloudTextRecognizer();
  final DocumentTextRecognizer _cloudDocumentRecognizer =
      FirebaseVision.instance.cloudDocumentTextRecognizer();

  Future<void> _getAndScanImage() async {
    setState(() {
      _imageFile = null;
      _imageSize = null;
    });

    final picker = ImagePicker();

    final pickedImage = await picker.getImage(source: ImageSource.gallery);
    final imageFile = pickedImage != null ? File(pickedImage.path) : null;

    setState(() {
      _imageFile = imageFile;
    });

    if (imageFile != null) {
      await Future.wait([
        _getImageSize(imageFile),
        _scanImage(imageFile),
      ]);
    }
  }

  Future<void> _getImageSize(File imageFile) async {
    final Completer<Size> completer = Completer<Size>();

    final Image image = Image.file(imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );

    final Size imageSize = await completer.future;
    setState(() {
      _imageSize = imageSize;
    });
  }

  Future<void> _scanImage(File imageFile) async {
    setState(() {
      _scanResults = null;
    });

    final FirebaseVisionImage visionImage =
        FirebaseVisionImage.fromFile(imageFile);

    dynamic results;
    switch (_currentDetector) {
      case Detector.barcode:
        results = await _barcodeDetector.detectInImage(visionImage);
        break;
      case Detector.face:
        results = await _faceDetector.processImage(visionImage);
        break;
      case Detector.label:
        results = await _imageLabeler.processImage(visionImage);
        break;
      case Detector.cloudLabel:
        results = await _cloudImageLabeler.processImage(visionImage);
        break;
      case Detector.text:
        results = await _recognizer.processImage(visionImage);
        break;
      case Detector.cloudText:
        results = await _cloudRecognizer.processImage(visionImage);
        break;
      case Detector.cloudDocumentText:
        results = await _cloudDocumentRecognizer.processImage(visionImage);
        break;
      default:
        return;
    }

    setState(() {
      _scanResults = results;
    });
  }

  CustomPaint _buildResults(Size imageSize, dynamic results) {
    CustomPainter painter;

    switch (_currentDetector) {
      case Detector.barcode:
        painter = BarcodeDetectorPainter(imageSize, results);
        break;
      case Detector.face:
        painter = FaceDetectorPainter(imageSize, results);
        break;
      case Detector.label:
        painter = LabelDetectorPainter(imageSize, results);
        break;
      case Detector.cloudLabel:
        painter = LabelDetectorPainter(imageSize, results);
        break;
      case Detector.text:
        painter = TextDetectorPainter(imageSize, results);
        break;
      case Detector.cloudText:
        painter = TextDetectorPainter(imageSize, results);
        break;
      case Detector.cloudDocumentText:
        painter = DocumentTextDetectorPainter(imageSize, results);
        break;
    }

    return CustomPaint(
      painter: painter,
    );
  }

  Widget _buildImage() {
    return Container(
      constraints: const BoxConstraints.expand(),
      decoration: BoxDecoration(
        image: _imageFile == null
            ? null
            : DecorationImage(
                image: Image.file(_imageFile!).image,
                fit: BoxFit.fill,
              ),
      ),
      child: _imageSize == null || _scanResults == null
          ? const Center(
              child: Text(
                'Scanning...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 30,
                ),
              ),
            )
          : _buildResults(_imageSize!, _scanResults),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Picture Scanner'),
        actions: <Widget>[
          PopupMenuButton<Detector>(
            onSelected: (Detector result) {
              // _scanResults = null;
              _currentDetector = result;
              if (_imageFile != null) _scanImage(_imageFile!);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<Detector>>[
              const PopupMenuItem<Detector>(
                value: Detector.barcode,
                child: Text('Detect Barcode'),
              ),
              const PopupMenuItem<Detector>(
                value: Detector.face,
                child: Text('Detect Face'),
              ),
              const PopupMenuItem<Detector>(
                value: Detector.label,
                child: Text('Detect Label'),
              ),
              const PopupMenuItem<Detector>(
                value: Detector.cloudLabel,
                child: Text('Detect Cloud Label'),
              ),
              const PopupMenuItem<Detector>(
                value: Detector.text,
                child: Text('Detect Text'),
              ),
              const PopupMenuItem<Detector>(
                value: Detector.cloudText,
                child: Text('Detect Cloud Text'),
              ),
              const PopupMenuItem<Detector>(
                value: Detector.cloudDocumentText,
                child: Text('Detect Document Text'),
              ),
            ],
          ),
        ],
      ),
      body: _imageFile == null
          ? const Center(child: Text('No image selected.'))
          : _buildImage(),
      floatingActionButton: FloatingActionButton(
        onPressed: _getAndScanImage,
        tooltip: 'Pick Image',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  @override
  void dispose() {
    _barcodeDetector.close();
    _faceDetector.close();
    _imageLabeler.close();
    _cloudImageLabeler.close();
    _recognizer.close();
    _cloudRecognizer.close();
    super.dispose();
  }
}
