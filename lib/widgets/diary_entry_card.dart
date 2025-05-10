import 'package:flutter/material.dart';
import 'package:koylum/models/diary_entry.dart';
import 'package:intl/intl.dart';

class DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;

  const DiaryEntryCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 0,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve tarih
          ListTile(
            title: Text(
              entry.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              DateFormat('dd MMMM yyyy', 'tr').format(entry.date),
            ),
            trailing: Chip(
              label: Text(entry.activityType ?? 'Genel'),
              backgroundColor: const Color(0xFF333333),
              labelStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
          // İçerik
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(entry.content),
          ),
          // Medya
          if (entry.mediaUrls != null && entry.mediaUrls!.isNotEmpty)
            SizedBox(
              height: 200,
              child: PageView.builder(
                itemCount: entry.mediaUrls!.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    entry.mediaUrls![index],
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
