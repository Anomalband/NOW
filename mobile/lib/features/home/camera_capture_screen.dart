import "dart:typed_data";

import "package:camera/camera.dart";
import "package:flutter/material.dart";

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({required this.camera, super.key});

  final CameraDescription camera;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  late final CameraController _controller;
  bool _isReady = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Kamera acilamadi.")));
      Navigator.of(context).pop();
    }
  }

  Future<void> _capture() async {
    if (_isCapturing || !_isReady) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final file = await _controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<Uint8List>(bytes);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Fotograf cekilemedi.")));
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isReady)
              CameraPreview(_controller)
            else
              const Center(child: CircularProgressIndicator()),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: FloatingActionButton.large(
                  heroTag: "capture",
                  onPressed: _capture,
                  child: _isCapturing
                      ? const CircularProgressIndicator(strokeWidth: 2.2)
                      : const Icon(Icons.camera_alt_rounded, size: 34),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
