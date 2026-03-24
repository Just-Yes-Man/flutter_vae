import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAE Digit Generator',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const VaeHomePage(),
    );
  }
}

class VaeHomePage extends StatefulWidget {
  const VaeHomePage({super.key});

  @override
  State<VaeHomePage> createState() => _VaeHomePageState();
}

class _VaeHomePageState extends State<VaeHomePage> {
  static const String _endpoint =
      'http://localhost:8501/v1/models/vae_model:predict';

  final TextEditingController _digitController = TextEditingController(text: '3');

  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _digitController.dispose();
    super.dispose();
  }

  Future<void> _generateDigit() async {
    final int? digit = int.tryParse(_digitController.text.trim());

    if (digit == null || digit < 0 || digit > 9) {
      setState(() {
        _errorMessage = 'Ingresa un dígito válido entre 0 y 9.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _imageBytes = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'instances': <Map<String, int>>[
                <String, int>{'digit': digit},
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}. Respuesta: ${response.body}',
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      final Uint8List pngBytes = _extractPngFromResponse(decoded);

      setState(() {
        _imageBytes = pngBytes;
      });
    } catch (error) {
      setState(() {
        _errorMessage =
            'No se pudo generar la imagen. Error: $error\n\n'
            'Si usas emulador Android, cambia localhost por 10.0.2.2.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Uint8List _extractPngFromResponse(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Formato JSON no soportado.');
    }

    final dynamic predictions = decoded['predictions'];
    if (predictions is! List || predictions.isEmpty) {
      throw Exception('No se encontraron "predictions" en la respuesta.');
    }

    final dynamic first = predictions.first;

    if (first is List) {
      return _pngFromFlatPixels(first);
    }

    if (first is Map<String, dynamic>) {
      final dynamic base64Image = first['image_base64'] ?? first['image'];
      if (base64Image is String) {
        final String normalized = base64Image.contains(',')
            ? base64Image.split(',').last
            : base64Image;
        return base64Decode(normalized);
      }

      final dynamic pixels = first['pixels'];
      if (pixels is List) {
        return _pngFromFlatPixels(pixels);
      }
    }

    throw Exception(
      'Formato de predicción no soportado. Se esperaba base64 o 784 pixeles.',
    );
  }

  Uint8List _pngFromFlatPixels(List<dynamic> rawPixels) {
    if (rawPixels.length != 784) {
      throw Exception(
        'Se esperaban 784 valores para una imagen 28x28 y llegaron ${rawPixels.length}.',
      );
    }

    final img.Image image = img.Image(width: 28, height: 28);

    for (int index = 0; index < rawPixels.length; index++) {
      final int x = index % 28;
      final int y = index ~/ 28;
      final double value = (rawPixels[index] as num).toDouble();
      final int gray = (value <= 1.0 ? value * 255.0 : value)
          .clamp(0, 255)
          .round();
      image.setPixelRgba(x, y, gray, gray, gray, 255);
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VAE Digit Generator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Escribe el número (0-9) para generar su imagen con el modelo VAE.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _digitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número a generar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateDigit,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generar imagen'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              )
            else if (_imageBytes != null)
              Expanded(
                child: Column(
                  children: <Widget>[
                    const Text('Resultado:'),
                    const SizedBox(height: 12),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.memory(
                          _imageBytes!,
                          filterQuality: FilterQuality.none,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text('Aún no hay imagen generada.'),
          ],
        ),
      ),
    );
  }
}
