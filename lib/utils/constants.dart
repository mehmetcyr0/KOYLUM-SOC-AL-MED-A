import 'package:flutter/material.dart';

const kInputDecoration = InputDecoration(
  filled: true,
  fillColor: Color(0xFF1E1E1E),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Color(0xFF333333)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
  ),
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
);
