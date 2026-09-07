import 'package:flutter/material.dart';

import 'landing_page.dart';

Widget buildSidebarItem(
  IconData icon,
  String title,
  bool isActive,
  BuildContext context, {
  bool isLogout = false,
}) {
  return ListTile(
    leading: Icon(
      icon,
      color: isActive
          ? Theme.of(context).colorScheme.secondary
          : Colors.white70,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: isActive
            ? Theme.of(context).colorScheme.secondary
            : Colors.white70,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    onTap: () {
      if (isLogout) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
      }
    },
  );
}

Widget buildStatCard(String title, String count, Color accentColor) {
  return Container(
    width: 250,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 5,
          spreadRadius: 1,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 10),
        Text(
          count,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      ],
    ),
  );
}
