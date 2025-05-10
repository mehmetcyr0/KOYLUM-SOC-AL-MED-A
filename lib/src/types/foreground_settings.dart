import 'package:flutter/material.dart';

class ForegroundSettings {
  final Color backgroundColor;
  
  const ForegroundSettings({
    required this.backgroundColor,
  });
  
  // Color.toARGB32 hatası düzeltme
  int getColorValue(Color color) {
    // Eski kod:
    // int colorValue = color.toARGB32();
    
    // Yeni kod:
    return color.value; // Color sınıfının value özelliğini kullanın
  }
}
