import 'package:flutter/material.dart';

class AuthenticationGrid extends StatefulWidget {
  const AuthenticationGrid({super.key});

  @override
  State<AuthenticationGrid> createState() => _AuthenticationGridState();
}

class _AuthenticationGridState extends State<AuthenticationGrid> {
  // This list will keep track of the sequence of tiles the user selects
  List<int> selectedTiles = [];

  void _handleTileTap(int index) {
    setState(() {
      if (selectedTiles.contains(index)) {
        // Deselect if already selected
        selectedTiles.remove(index);
      } else {
        // Add to the selection pattern
        selectedTiles.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Grid')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 columns wide
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 12, // 12 total cards/tiles
            itemBuilder: (context, index) {
              bool isSelected = selectedTiles.contains(index);
              
              return GestureDetector(
                onTap: () => _handleTileTap(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blueAccent : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
