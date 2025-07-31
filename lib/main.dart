import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum LetterStatus { initial, correct, partial, wrong }

class GameStats {
  int total;
  int won;
  List<int> distribution;

  GameStats({this.total = 0, this.won = 0, List<int>? distribution})
      : distribution = distribution ?? List.filled(6, 0);

  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      total: json['total'] ?? 0,
      won: json['won'] ?? 0,
      distribution:
          (json['distribution'] as List<dynamic>?)?.map((e) => e as int).toList() ??
              List.filled(6, 0),
    );
  }

  Map<String, dynamic> toJson() =>
      {'total': total, 'won': won, 'distribution': distribution};
}

String removeDiacritics(String str) {
  const withAccent =
      'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç';
  const withoutAccent =
      'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc';
  for (var i = 0; i < withAccent.length; i++) {
    str = str.replaceAll(withAccent[i], withoutAccent[i]);
  }
  return str;
}

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

  bool _ignoreAccentuation = true;
  bool _realWordsOnly = true;
  bool _jumpToNextLine = true;
  bool _tutorialShown = false;

  late GameStats _wordDayStats;
  late GameStats _generalStats;
  int _currentStreak = 0;
  String _lastCompletedDate = '';

  List<String> _normalizedDictionary = [];

  List<String> _dictionary = [];
  String _secretWord = '';
  bool _gameOver = false;
  bool _won = false;
  bool _usingDailyWord = false;
  late String _todayKey;
  bool _playedToday = false;

  late Timer _timer;
  String _countdown = '';

  bool _useDeviceKeyboard = true;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();

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
    await _loadPreferences();
    await _loadState();
    _startCountdown();
    if (_useDeviceKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
    if (!_tutorialShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showHelpDialog();
      });
    }
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
    _normalizedDictionary =
        _dictionary.map((w) => removeDiacritics(w)).toList();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _ignoreAccentuation = prefs.getBool('ignoreAccentuation') ?? true;
    _realWordsOnly = prefs.getBool('realWordsOnly') ?? true;
    _jumpToNextLine = prefs.getBool('jumpToNextLine') ?? true;
    _tutorialShown = prefs.getBool('tutorialShown') ?? false;
    _useDeviceKeyboard = prefs.getBool('useDeviceKeyboard') ?? true;
    _currentStreak = prefs.getInt('currentStreak') ?? 0;
    _lastCompletedDate = prefs.getString('lastCompletedDate') ?? '';
    final dailyJson = prefs.getString('dailyStats');
    final generalJson = prefs.getString('generalStats');
    _wordDayStats =
        dailyJson != null ? GameStats.fromJson(json.decode(dailyJson)) : GameStats();
    _generalStats = generalJson != null
        ? GameStats.fromJson(json.decode(generalJson))
        : GameStats();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('ignoreAccentuation', _ignoreAccentuation);
    prefs.setBool('realWordsOnly', _realWordsOnly);
    prefs.setBool('jumpToNextLine', _jumpToNextLine);
    prefs.setBool('tutorialShown', _tutorialShown);
    prefs.setBool('useDeviceKeyboard', _useDeviceKeyboard);
    prefs.setInt('currentStreak', _currentStreak);
    prefs.setString('lastCompletedDate', _lastCompletedDate);
    prefs.setString('dailyStats', json.encode(_wordDayStats.toJson()));
    prefs.setString('generalStats', json.encode(_generalStats.toJson()));
  }

  @override
  void dispose() {
    _timer.cancel();
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onRawKey(RawKeyEvent event) {
    if (!_useDeviceKeyboard) return;
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _handleKey('ENTER');
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _handleKey('BACK');
      } else {
        final key = event.character?.toUpperCase();
        if (key != null && key.length == 1 && RegExp(r'^[A-Z]$').hasMatch(key)) {
          _handleKey(key);
        }
      }
    }
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
        if (_currentCol == cols && _jumpToNextLine) {
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

  void _recordGameResult(bool won) {
    final attempts = _currentRow + 1;
    if (_usingDailyWord) {
      _wordDayStats.total++;
      if (won) {
        _wordDayStats.won++;
        _wordDayStats.distribution[attempts - 1]++;
        final yesterday = DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10);
        if (_lastCompletedDate == yesterday) {
          _currentStreak++;
        } else if (_lastCompletedDate != _todayKey) {
          _currentStreak = 1;
        }
        _lastCompletedDate = _todayKey;
      } else {
        _currentStreak = 0;
      }
    }
    _generalStats.total++;
    if (won) {
      _generalStats.won++;
      _generalStats.distribution[attempts - 1]++;
    }
    _savePreferences();
  }

  void _submitGuess() {
    final guess = _board[_currentRow].join().toUpperCase();
    final normalizedGuess =
        _ignoreAccentuation ? removeDiacritics(guess) : guess;
    final dict = _ignoreAccentuation ? _normalizedDictionary : _dictionary;
    if (_realWordsOnly && !dict.contains(normalizedGuess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Palavra inválida')),
      );
      return;
    }

    final target =
        _ignoreAccentuation ? removeDiacritics(_secretWord) : _secretWord;
    for (var i = 0; i < cols; i++) {
      final letter = guess[i];
      final normLetter =
          _ignoreAccentuation ? removeDiacritics(letter) : letter;
      if (normLetter == target[i]) {
        _status[_currentRow][i] = LetterStatus.correct;
      } else if (target.contains(normLetter)) {
        _status[_currentRow][i] = LetterStatus.partial;
      } else {
        _status[_currentRow][i] = LetterStatus.wrong;
      }
    }

    final isCorrect = normalizedGuess == target;
    if (isCorrect) {
      _gameOver = true;
      _won = true;
      _playedToday = true;
      _recordGameResult(true);
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
      _recordGameResult(false);
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
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showStatsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
          TextButton(
            onPressed: _showAboutDialog,
            child: const Text('Sobre', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _onRawKey,
        child: Column(
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
          if (_useDeviceKeyboard)
            Offstage(
              offstage: true,
              child: TextField(
                focusNode: _focusNode,
                controller: _textController,
                autofocus: true,
                onChanged: (_) => _textController.clear(),
                decoration: const InputDecoration(border: InputBorder.none),
                style: const TextStyle(fontSize: 0),
              ),
            )
          else
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
    if (_useDeviceKeyboard) return const SizedBox.shrink();
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Como jogar'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adivinhe a senha em até 6 tentativas;'),
              Text('Cada tentativa deve conter uma palavra válida de 5 letras;'),
              Text('Não precisa acertar a acentuação;'),
              Text('Após cada tentativa as letras corretas serão sinalizadas com cores diferentes;'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _tutorialShown = true;
              _savePreferences();
              Navigator.pop(context);
            },
            child: const Text('Jogar agora'),
          )
        ],
      ),
    );
  }

  Widget _statsBars(GameStats stats) {
    final maxVal = stats.won == 0
        ? 1
        : stats.distribution.reduce((a, b) => a > b ? a : b);
    return Column(
      children: List.generate(6, (i) {
        final val = stats.distribution[i];
        return Row(
          children: [
            SizedBox(width: 20, child: Text('${i + 1}')),
            Expanded(
              child: LinearProgressIndicator(
                value: val / maxVal,
              ),
            ),
            SizedBox(width: 30, child: Text(' $val')),
          ],
        );
      }),
    );
  }

  Widget _buildStatsContent(GameStats stats, {bool showStreak = false}) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text('Partidas'),
                  Text('${stats.total}'),
                ],
              ),
              Column(
                children: [
                  const Text('Acertos'),
                  Text('${stats.won}'),
                ],
              ),
              if (showStreak)
                Column(
                  children: [
                    const Text('Consecutivos'),
                    Text('$_currentStreak'),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          _statsBars(stats),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Estatísticas'),
        content: SizedBox(
          width: double.maxFinite,
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(tabs: [
                  Tab(text: 'Palavra do dia'),
                  Tab(text: 'Geral'),
                ]),
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    children: [
                      _buildStatsContent(_wordDayStats, showStreak: true),
                      _buildStatsContent(_generalStats),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'))
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
        context: context,
        builder: (ctx) {
          bool ignoreAcc = _ignoreAccentuation;
          bool realOnly = _realWordsOnly;
          bool jump = _jumpToNextLine;
          bool deviceKb = _useDeviceKeyboard;
          return StatefulBuilder(builder: (ctx, setStateSB) {
            return AlertDialog(
              title: const Text('Configurações'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Ignorar acentuação'),
                    value: ignoreAcc,
                    onChanged: (v) => setStateSB(() => ignoreAcc = v ?? true),
                  ),
                  CheckboxListTile(
                    title: const Text('Apenas palavras reais'),
                    value: realOnly,
                    onChanged: (v) => setStateSB(() => realOnly = v ?? true),
                  ),
                  CheckboxListTile(
                    title: const Text(
                        'Passar automaticamente para a próxima linha'),
                    value: jump,
                    onChanged: (v) => setStateSB(() => jump = v ?? true),
                  ),
                  CheckboxListTile(
                    title: const Text('Usar teclado do dispositivo'),
                    value: deviceKb,
                    onChanged: (v) => setStateSB(() => deviceKb = v ?? true),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      setState(() {
                        _ignoreAccentuation = ignoreAcc;
                        _realWordsOnly = realOnly;
                        _jumpToNextLine = jump;
                        _useDeviceKeyboard = deviceKb;
                      });
                      if (_useDeviceKeyboard) {
                        _focusNode.requestFocus();
                      }
                      _savePreferences();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Fechar'))
              ],
            );
          });
        });
  }

  void _showAboutDialog() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Sobre'),
              content: const Text(
                  'Adaptação em português do Wordle por Josh Wardle.\nSuper senha foi desenvolvido por Vinicius Perdigão como um exercício.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'))
              ],
            ));
  }
}
