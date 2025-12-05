import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart'; // Changed from shared_preferences to Firestore
import '../models/order_model.dart';

class PrinterService {
  final int _printerPort = 9100;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Default fallback
  static const String _defaultIp = '192.168.1.100';

  // --- CONFIGURATION METHODS (Firestore) ---

  Future<String> getStoredIp() async {
    try {
      // Fetch from the 'config' collection, document 'printer'
      final doc = await _db.collection('config').doc('printer').get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('ip')) {
        return doc.data()!['ip'] as String;
      }
    } catch (e) {
      print("Error fetching printer IP: $e");
    }
    return _defaultIp;
  }

  Future<void> savePrinterIp(String ip) async {
    // Save to the 'config' collection, document 'printer'
    await _db.collection('config').doc('printer').set({'ip': ip});
  }

  // --- PRINTING LOGIC ---

  Future<String> printReceipt(OrderModel order, double total) async {
    Socket? socket;
    try {
      // 1. Get IP from Cloud
      final printerIp = await getStoredIp();
      print("Attempting to connect to $printerIp:$_printerPort...");

      socket = await Socket.connect(printerIp, _printerPort, timeout: const Duration(seconds: 3));
      print("Connected to printer!");

      final List<int> bytes = [];

      // -- Init Printer --
      bytes.addAll([0x1B, 0x40]);

      // -- Center Align --
      bytes.addAll([0x1B, 0x61, 0x01]);

      // --- LOGO SUPERIOR ---
      try {
        final ByteData data = await rootBundle.load('assets/images/Logo_Panzon_BN.png');
        final Uint8List imgBytes = data.buffer.asUint8List();
        final img.Image? originalImage = img.decodeImage(imgBytes);

        if (originalImage != null) {
          final img.Image resized = img.copyResize(originalImage, width: 350);
          bytes.addAll(_generatorImage(resized));
          bytes.addAll(_utf8("\n")); // Spacer
        }
      } catch (e) {
        print("Error processing logo: $e");
        bytes.addAll(_utf8("[EL PANZON]\n"));
      }

      // -- Title --
      bytes.addAll([0x1D, 0x21, 0x11]); // Double Size
      bytes.addAll(_utf8("EL PANZON\n"));
      bytes.addAll([0x1D, 0x21, 0x00]); // Reset size

      bytes.addAll(_utf8("Tacos & Bebidas\n"));
      bytes.addAll(_utf8("--------------------------------\n"));

      // -- Left Align --
      bytes.addAll([0x1B, 0x61, 0x00]);

      // -- Order Info --
      String id = order.tableNumber == 0
          ? "Para Llevar: ${order.customerName ?? 'Cliente'}"
          : "Mesa: ${order.tableNumber}";

      bytes.addAll(_utf8("Fecha: ${_formatDate(DateTime.now())}\n"));
      bytes.addAll(_utf8("Orden: #${order.orderNumber}\n"));
      bytes.addAll(_utf8("$id\n"));
      bytes.addAll(_utf8("--------------------------------\n"));

      // -- Items --
      order.tacoCounts.forEach((name, qty) {
        bytes.addAll(_utf8(_formatLineItem(qty, name)));
      });
      order.simpleExtraCounts.forEach((name, qty) {
        bytes.addAll(_utf8(_formatLineItem(qty, name)));
      });
      order.sodaCounts.forEach((name, temps) {
        int qty = (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
        if (qty > 0) {
          bytes.addAll(_utf8(_formatLineItem(qty, name)));
        }
      });

      bytes.addAll(_utf8("--------------------------------\n"));

      // -- Total --
      bytes.addAll([0x1B, 0x61, 0x02]); // Right align
      bytes.addAll([0x1D, 0x21, 0x01]); // Double Height
      bytes.addAll(_utf8("TOTAL: \$${total.toStringAsFixed(2)}\n"));
      bytes.addAll([0x1D, 0x21, 0x00]); // Reset

      // -- Footer (IMAGEN INFERIOR) --
      bytes.addAll([0x1B, 0x61, 0x01]); // Center Align
      bytes.addAll(_utf8("\n")); // Spacer

      try {
        final ByteData footerData = await rootBundle.load('assets/images/Panzon_BN_visita.png');
        final Uint8List footerBytes = footerData.buffer.asUint8List();
        final img.Image? footerImage = img.decodeImage(footerBytes);

        if (footerImage != null) {
          final img.Image resizedFooter = img.copyResize(footerImage, width: 350);
          bytes.addAll(_generatorImage(resizedFooter));
        }
      } catch (e) {
        print("Error processing footer image: $e");
      }

      bytes.addAll(_utf8("\n\n\n")); // Feed

      // -- Cut Paper --
      bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

      // 3. Send Data
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();

      return "Success";

    } catch (e) {
      print("Error printing: $e");
      return "Error: $e";
    } finally {
      await socket?.close();
    }
  }

  // --- Image to ESC/POS Raster Converter ---
  List<int> _generatorImage(img.Image image) {
    List<int> bytes = [];
    final img.Image gray = img.grayscale(image);
    final int width = gray.width;
    final int height = gray.height;
    final int xL = (width + 7) ~/ 8;

    bytes.addAll([0x1D, 0x76, 0x30, 0x00]);
    bytes.addAll([xL % 256, xL ~/ 256]);
    bytes.addAll([height % 256, height ~/ 256]);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x += 8) {
        int byte = 0;
        for (int b = 0; b < 8; b++) {
          if (x + b < width) {
            final pixel = gray.getPixel(x + b, y);
            final lum = pixel.luminance;
            final alpha = pixel.a;

            if (alpha > 128 && lum < 128) {
              byte |= (1 << (7 - b));
            }
          }
        }
        bytes.add(byte);
      }
    }
    return bytes;
  }

  List<int> _utf8(String text) {
    var clean = text
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u')
        .replaceAll('ñ', 'n').replaceAll('Ñ', 'N');
    return clean.codeUnits;
  }

  String _formatLineItem(int qty, String name) {
    String q = "$qty x ";
    if (name.length > 25) name = name.substring(0, 25);
    return "$q$name\n";
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}";
  }
}