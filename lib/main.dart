import 'package:flutter/material.dart';

void main() {
  runApp(const SuperSenhaApp());
}

class SuperSenhaApp extends StatelessWidget {
  const SuperSenhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Senha',
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const int rows = 6;
  static const int cols = 5;
  final List<List<String>> _board =
      List.generate(rows, (_) => List.filled(cols, ''));
  int _currentRow = 0;
  int _currentCol = 0;

  void _handleKey(String key) {
    setState(() {
      if (key == 'ENTER') {
        if (_currentCol == cols) {
          _currentRow = (_currentRow + 1).clamp(0, rows - 1);
          _currentCol = 0;
        }
      } else if (key == 'BACK') {
        if (_currentCol > 0) {
          _currentCol--;
          _board[_currentRow][_currentCol] = '';
        }
      } else if (_currentCol < cols && key.length == 1) {
        _board[_currentRow][_currentCol] = key;
        _currentCol++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Super Senha')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildBoard(),
          const SizedBox(height: 24),
          _buildKeyboard(),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Column(
      children: List.generate(rows, (r) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cols, (c) {
            final letter = _board[r][c];
            return Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              alignment: Alignment.center,
              child: Text(letter.toUpperCase(),
                  style: const TextStyle(fontSize: 18)),
            );
          }),
        );
      }),
    );
  }

  Widget _buildKeyboard() {
    const letters = 'QWERTYUIOPASDFGHJKLZXCVBNM';
    final keys = [
      ...letters.split(''),
      'BACK',
      'ENTER',
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      children: keys.map((k) {
        return Padding(
          padding: const EdgeInsets.all(4),
          child: ElevatedButton(
            onPressed: () => _handleKey(k),
            child: Text(k.length == 1 ? k : (k == 'BACK' ? '⌫' : '⏎')),
          ),
        );
      }).toList(),
    );
  }
}
