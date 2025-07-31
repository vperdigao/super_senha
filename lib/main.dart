import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum LetterStatus { initial, correct, partial, wrong }

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
  late List<List<LetterStatus>> _status;
  int _currentRow = 0;
  int _currentCol = 0;

  List<String> _dictionary = [];
  String _secretWord = '';
  bool _gameOver = false;
  bool _won = false;
  bool _usingDailyWord = false;
  late String _todayKey;
  bool _playedToday = false;

  late Timer _timer;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _status =
        List.generate(rows, (_) => List.filled(cols, LetterStatus.initial));
    _todayKey = DateTime.now().toIso8601String().substring(0, 10);
    _initializeGame();
  }

  void _startCountdown() {
    void update() {
      final now = DateTime.now();
      final nextMidnight = DateTime(now.year, now.month, now.day + 1);
      final remaining = nextMidnight.difference(now);
      final hours = remaining.inHours.remainder(24).toString().padLeft(2, '0');
      final minutes =
          remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds =
          remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() {
        _countdown = '$hours:$minutes:$seconds';
      });
    }

    update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => update());
  }

  Future<void> _initializeGame() async {
    await _loadDictionary();
    await _loadState();
    _startCountdown();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('wordOfDayDate');
    final completed = prefs.getBool('dailyCompleted') ?? false;

    if (savedDate == _todayKey && !completed) {
      final boardJson = prefs.getString('board');
      final statusJson = prefs.getString('status');
      _secretWord = prefs.getString('wordOfDayWord') ?? '';
      _currentRow = prefs.getInt('currentRow') ?? 0;
      _currentCol = prefs.getInt('currentCol') ?? 0;
      if (boardJson != null) {
        final List<dynamic> boardList = json.decode(boardJson);
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            _board[r][c] = boardList[r][c];
          }
        }
      }
      if (statusJson != null) {
        final List<dynamic> statusList = json.decode(statusJson);
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            _status[r][c] =
                LetterStatus.values[statusList[r][c] as int];
          }
        }
      }
      _usingDailyWord = true;
      _playedToday = false;
      _gameOver = prefs.getBool('gameOver') ?? false;
      _won = prefs.getBool('won') ?? false;
    } else {
      _playedToday = savedDate == _todayKey && completed;
      if (!_playedToday) {
        _secretWord = await _fetchWordOfDay();
        _usingDailyWord = true;
        await _saveState();
      } else {
        _startRandomWord();
        await _saveState();
      }
    }
  }

  Future<String> _fetchWordOfDay() async {
    try {
      final response =
          await http.get(Uri.parse('https://vini.me/supersenha/supersenha.asp'));
      if (response.statusCode == 200) {
        return response.body.trim().toUpperCase();
      }
    } catch (_) {}
    final index = DateTime.now().millisecondsSinceEpoch % _dictionary.length;
    return _dictionary[index];
  }

  void _startRandomWord() {
    final rand = Random();
    _usingDailyWord = false;
    _secretWord = _dictionary[rand.nextInt(_dictionary.length)];
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_usingDailyWord) {
      await prefs.remove('board');
      await prefs.remove('status');
      await prefs.remove('wordOfDayWord');
      await prefs.remove('currentRow');
      await prefs.remove('currentCol');
      await prefs.remove('gameOver');
      await prefs.remove('won');
      await prefs.setBool('dailyCompleted', _playedToday);
      return;
    }
    prefs.setString('wordOfDayDate', _todayKey);
    prefs.setString('wordOfDayWord', _secretWord);
    prefs.setInt('currentRow', _currentRow);
    prefs.setInt('currentCol', _currentCol);
    prefs.setBool('gameOver', _gameOver);
    prefs.setBool('won', _won);
    prefs.setBool('dailyCompleted', _gameOver);
    prefs.setString('board', json.encode(_board));
    final statusList =
        _status.map((row) => row.map((e) => e.index).toList()).toList();
    prefs.setString('status', json.encode(statusList));
  }

  Future<void> _loadDictionary() async {
    try {
      final response =
          await http.get(Uri.parse('https://vini.me/supersenha/dicionario.js'));
      if (response.statusCode == 200) {
        final text = response.body;
        final start = text.indexOf('[');
        final end = text.lastIndexOf(']');
        final jsonList = text.substring(start, end + 1).replaceAll("'", '"');
        final List<dynamic> words = json.decode(jsonList);
        _dictionary =
            words.map((w) => w.toString().toUpperCase()).toList();
      }
    } catch (_) {}

    if (_dictionary.isEmpty) {
      final data = await rootBundle.loadString('assets/words.json');
      final List<dynamic> words = json.decode(data);
      _dictionary = words.map((w) => w.toString().toUpperCase()).toList();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleKey(String key) {
    if (_gameOver) return;
    setState(() {
      if (key == 'ENTER') {
        if (_currentCol == cols) {
          _submitGuess();
        }
      } else if (key == 'BACK') {
        if (_currentCol > 0) {
          _currentCol--;
          _board[_currentRow][_currentCol] = '';
        }
      } else if (_currentCol < cols && key.length == 1) {
        _board[_currentRow][_currentCol] = key;
        _currentCol++;
        if (_currentCol == cols) {
          _submitGuess();
        }
      }
    });
    _saveState();
  }

  void _resetGameRandom() {
    setState(() {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          _board[r][c] = '';
        }
      }
      _currentRow = 0;
      _currentCol = 0;
      _status =
          List.generate(rows, (_) => List.filled(cols, LetterStatus.initial));
      _gameOver = false;
      _won = false;
      _startRandomWord();
    });
    _saveState();
  }

  void _submitGuess() {
    final guess = _board[_currentRow].join().toUpperCase();
    if (!_dictionary.contains(guess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Palavra inválida')),
      );
      return;
    }

    for (var i = 0; i < cols; i++) {
      final letter = guess[i];
      if (letter == _secretWord[i]) {
        _status[_currentRow][i] = LetterStatus.correct;
      } else if (_secretWord.contains(letter)) {
        _status[_currentRow][i] = LetterStatus.partial;
      } else {
        _status[_currentRow][i] = LetterStatus.wrong;
      }
    }

    if (guess == _secretWord) {
      _gameOver = true;
      _won = true;
      _playedToday = true;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Você acertou a palavra do dia!!!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('A palavra correta é:'),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {},
                child: Text(_secretWord.toUpperCase()),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Não se esqueça de voltar amanhã para descobrir a palavra do dia.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetGameRandom();
                },
                child: const Text('Jogar novamente'),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                  'Será que seus amigos conseguem? Compartilhe e descubra!'),
            )
          ],
        ),
      );
    } else if (_currentRow == rows - 1) {
      _gameOver = true;
      _playedToday = true;
      bool reveal = false;
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setStateSB) {
          return AlertDialog(
            title: const Text('Não foi desta vez'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('A palavra correta é:'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setStateSB(() => reveal = true),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(reveal ? _secretWord.toUpperCase() : 'Clique para ver'),
                ),
                if (reveal)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('https://dicio.com.br/${_secretWord.toLowerCase()}'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                    'Será que seus amigos conseguem? Compartilhe e descubra!'),
              )
            ],
          );
        }),
      );
    } else {
      _currentRow++;
      _currentCol = 0;
    }

    _saveState();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Super Senha '),
            Icon(_won ? Icons.lock_open : Icons.lock),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Sobre', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'Próxima palavra do dia em: $_countdown',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildBoard(),
          const SizedBox(height: 24),
          _buildKeyboard(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _resetGameRandom,
            child: const Text('Jogar novamente'),
          ),
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
            final status = _status[r][c];
            Color bgColor;
            switch (status) {
              case LetterStatus.correct:
                bgColor = Colors.green;
                break;
              case LetterStatus.partial:
                bgColor = Colors.yellow;
                break;
              case LetterStatus.wrong:
                bgColor = Colors.grey.shade800;
                break;
              default:
                bgColor = Colors.transparent;
            }
            return Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                color: bgColor,
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
            onPressed: _gameOver ? null : () => _handleKey(k),
            child: Text(k.length == 1 ? k : (k == 'BACK' ? '⌫' : '⏎')),
          ),
        );
      }).toList(),
    );
  }
}
