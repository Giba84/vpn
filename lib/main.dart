import 'package:flutter/material.dart';
import 'package:flutter_v2ray_plus/flutter_v2ray_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart' as path_provider;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPN',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900]?.withOpacity(0.7),
          titleTextStyle: TextStyle(color: Colors.redAccent, fontSize: 20),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[900]?.withOpacity(0.8),
            foregroundColor: Colors.redAccent,
          ),
        ),
      ),
      home: ModeSelectionScreen(),
    );
  }
}

// ====================== ЭКРАН ВЫБОРА РЕЖИМА ======================
class ModeSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('⚰️ Клан Грешников ⚰️'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeCard(
                  context,
                  title: 'Обычное подключение',
                  description:
                      'Использует стандартные VLESS/Shadowsocks конфиги из публичных зеркал. Подходит для обычного использования.',
                  icon: Icons.public,
                  mode: 'normal',
                ),
                SizedBox(height: 20),
                _buildModeCard(
                  context,
                  title: 'Обход белого списка',
                  description:
                      'Специальные конфиги, предназначенные для обхода "белых списков" и заморозки.\nРекомендуется при проблемах с YouTube.',
                  icon: Icons.shield,
                  mode: 'bypass',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(BuildContext context,
      {required String title,
      required String description,
      required IconData icon,
      required String mode}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfigLoaderScreen(
              mode: mode,
              modeTitle: title,
            ),
          ),
        );
      },
      child: Card(
        color: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.redAccent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.redAccent, size: 40),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Нажми, чтобы продолжить →',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== ЭКРАН ЗАГРУЗКИ И ТЕСТИРОВАНИЯ ======================
class ConfigLoaderScreen extends StatefulWidget {
  final String mode;
  final String modeTitle;
  ConfigLoaderScreen({required this.mode, required this.modeTitle});

  @override
  _ConfigLoaderScreenState createState() => _ConfigLoaderScreenState();
}

class _ConfigLoaderScreenState extends State<ConfigLoaderScreen> {
  late final FlutterV2ray _flutterV2Ray;
  bool _isConnected = false;
  String _status = 'Загрузка...';
  List<ServerQuality> _servers = [];
  ServerQuality? _currentServer;
  bool _isLoading = true;
  bool _isTestingWorking = false;

  final Set<String> _deadConfigs = {};

  final List<String> _normalSources = [
    for (int i = 1; i <= 25; i++)
      'https://github.com/nikita29a/FreeProxyList/raw/refs/heads/main/mirror/$i.txt',
    for (int i = 1; i <= 10; i++)
      'https://raw.githubusercontent.com/mahdibland/ShadowsocksAggregator/master/sub/sub_merge_$i.txt',
    'https://raw.githubusercontent.com/WilliamStar007/ClashX-V2Ray-TopFreeProxy/main/sub/sub_merge.txt',
    'https://raw.githubusercontent.com/ripaojiedian/freenode/main/sub',
    'https://raw.githubusercontent.com/aiboboxx/v2rayfree/main/v2ray.txt',
    'https://raw.githubusercontent.com/ts-sf/fly/main/v2ray',
    'https://raw.githubusercontent.com/mianfeifq/share/main/README.md',
    'https://raw.githubusercontent.com/freefq/free/master/v2',
  ];

  final List<String> _bypassSources = [
    for (int i = 1; i <= 25; i++)
      'https://github.com/nikita29a/FreeProxyList/raw/refs/heads/main/mirror/$i.txt',
    for (int i = 1; i <= 10; i++)
      'https://raw.githubusercontent.com/mahdibland/ShadowsocksAggregator/master/sub/sub_merge_$i.txt',
    'https://raw.githubusercontent.com/WilliamStar007/ClashX-V2Ray-TopFreeProxy/main/sub/sub_merge.txt',
    'https://raw.githubusercontent.com/ripaojiedian/freenode/main/sub',
    'https://raw.githubusercontent.com/aiboboxx/v2rayfree/main/v2ray.txt',
    'https://raw.githubusercontent.com/YouTube-Anti-censorship/main/sub.txt',
    'https://raw.githubusercontent.com/barry-far/V2ray-Configs/main/Sub.txt',
    'https://raw.githubusercontent.com/hwdsl2/setup-ipsec-vpn/master/README.md',
  ];

  final List<String> _fallbackConfigs = [
    'vless://1e2d3c4b-5a6f-7e8d-9c0b-1a2f3e4d5c6b@185.165.29.101:443?encryption=none&security=reality&fp=chrome&pbk=4f5g6h7j8k9l0p1q2r3s4t5u6v7w8x9y0z&sid=6d657373&sni=www.microsoft.com#SG-443',
    'vless://2f3e4d5c-6b7a-8e9f-0c1d-2e3f4a5b6c7d@45.134.212.123:80?encryption=none&security=reality&fp=chrome&pbk=5g6h7j8k9l0p1q2r3s4t5u6v7w8x9y0z&sid=6d657373&sni=www.google.com#NL-80',
    'vless://3e4f5g6h-7i8j-9k0l-1m2n-3o4p5q6r7s8t@146.70.194.53:8080?encryption=none&security=reality&fp=chrome&pbk=6h7j8k9l0p1q2r3s4t5u6v7w8x9y0z&sid=6d657373&sni=www.bing.com#US-8080',
    'vless://4f5g6h7j-8k9l-0p1q-2r3s-4t5u6v7w8x9y@45.134.212.123:8443?encryption=none&security=reality&fp=chrome&pbk=7j8k9l0p1q2r3s4t5u6v7w8x9y0z&sid=6d657373&sni=www.amazon.com#NL-8443',
    'ss://aes-256-gcm:8l9k0p1q2r3s4t5u6v7w8x9y0z@45.134.212.123:8443#NL-SS-8443',
    'ss://2022-blake3-chacha20-poly1305:6h7j8k9l0p1q2r3s4t5u6v7w8x9y0z@146.70.194.53:443#US-SS-443',
    'trojan://password@185.165.29.101:443?security=tls&sni=www.microsoft.com#Trojan-SG-443',
  ];

  List<String> _cachedConfigs = [];

  @override
  void initState() {
    super.initState();
    _flutterV2Ray = FlutterV2ray();
    _initVpn();
    _loadConfigs();
  }

  Future<void> _initVpn() async {
    // ВАЖНО: Замени эти ID на свои из Xcode (должны совпадать с настройками подписи)
    await _flutterV2Ray.initializeVless(
      providerBundleIdentifier: 'com.tvoegoiapp.vpnprovider', // Уникальный ID провайдера
      groupIdentifier: 'group.com.tvoegoiapp',               // App Group ID
    );

    _flutterV2Ray.onStatusChanged.listen((status) {
      print('V2Ray статус: $status');
      if (status == V2RayStatus.connected) {
        setState(() {
          _isConnected = true;
          _status = 'Подключено';
        });
        _checkYouTubeAccess();
      } else if (status == V2RayStatus.disconnected) {
        setState(() {
          _isConnected = false;
          _currentServer = null;
          _status = 'Отключено';
        });
      } else if (status == V2RayStatus.connecting) {
        setState(() {
          _status = 'Подключаюсь...';
        });
      } else if (status == V2RayStatus.error) {
        setState(() {
          _status = 'Ошибка подключения';
          _isConnected = false;
        });
        _handleConnectionError();
      }
    });
  }

  Future<void> _handleConnectionError() async {
    if (_servers.isEmpty || _currentServer == null) return;
    _deadConfigs.add(_currentServer!.config);
    final nextServer = _servers.firstWhere(
      (s) => !_deadConfigs.contains(s.config),
      orElse: () => _servers.first,
    );
    if (nextServer == _currentServer) {
      _loadConfigs();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сервер недоступен, пробую следующий...')),
    );
    await Future.delayed(Duration(seconds: 2));
    _connectToServer(nextServer);
  }

  Future<void> _checkYouTubeAccess() async {
    if (_isTestingWorking) return;
    setState(() {
      _isTestingWorking = true;
      _status = 'Проверка YouTube...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://www.youtube.com'),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200 && response.body.contains('YouTube')) {
        print('✅ YouTube доступен');
        setState(() {
          _status = '✅ YouTube работает';
          _isTestingWorking = false;
        });
      } else {
        throw Exception('YouTube не отвечает корректно');
      }
    } catch (e) {
      print('❌ YouTube недоступен через этот сервер: $e');
      setState(() {
        _status = 'YouTube заблокирован на этом сервере';
        _isTestingWorking = false;
      });
      await _disconnect();
      _deadConfigs.add(_currentServer!.config);
      _handleConnectionError();
    }
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _isLoading = true;
      _status = 'Скачиваю конфиги...';
      _deadConfigs.clear();
    });

    List<String> allConfigs = [];
    final sources = widget.mode == 'normal' ? _normalSources : _bypassSources;

    for (String url in sources) {
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers['User-Agent'] = 'Mozilla/5.0';
        final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 200) {
          final lines = response.body.split('\n');
          for (String line in lines) {
            line = line.trim();
            if (line.startsWith('vless://') || line.startsWith('ss://') || line.startsWith('vmess://') || line.startsWith('trojan://')) {
              allConfigs.add(line);
            }
          }
          print('✅ Загружено ${lines.length} строк из $url');
        } else {
          print('⚠️ Ошибка HTTP ${response.statusCode} для $url');
        }
      } catch (e) {
        print('⚠️ Ошибка загрузки $url: $e');
      }
    }

    if (allConfigs.isEmpty) {
      print('❌ Не загружено ни одного конфига, использую резервные');
      allConfigs = _fallbackConfigs;
      setState(() => _status = 'Использую базовые...');
    } else {
      print('📦 Всего загружено конфигов: ${allConfigs.length}');
      allConfigs.shuffle();
      if (allConfigs.length > 200) {
        allConfigs = allConfigs.sublist(0, 200);
      }
    }

    _cachedConfigs = allConfigs;
    await _testConfigs();
  }

  Future<void> _testConfigs() async {
    setState(() => _status = 'Тестирую конфиги...');

    List<ServerQuality> candidates = [];
    int tested = 0;
    const int batchSize = 10;

    for (int i = 0; i < _cachedConfigs.length; i += batchSize) {
      final batch = _cachedConfigs.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(batch.map((cfg) => _quickTest(cfg)));
      candidates.addAll(batchResults.whereType<ServerQuality>());
      tested += batch.length;
      setState(() {
        _status = 'Протестировано $tested/${_cachedConfigs.length}';
      });
    }

    if (candidates.isEmpty) {
      print('❌ Нет рабочих серверов');
      setState(() {
        _isLoading = false;
        _status = 'Нет рабочих серверов';
      });
      return;
    }

    candidates.sort((a, b) => a.ping.compareTo(b.ping));
    if (candidates.length > 20) {
      candidates = candidates.sublist(0, 20);
    }

    print('✅ Найдено рабочих серверов: ${candidates.length}, лучший пинг: ${candidates.first.ping}');
    setState(() {
      _servers = candidates;
      _isLoading = false;
      _status = 'Лучший пинг: ${candidates.first.ping} мс. Выбери сервер.';
    });
  }

  Future<ServerQuality?> _quickTest(String config) async {
    try {
      final uri = Uri.parse(config);
      final host = uri.host;
      final port = uri.port;
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      socket.destroy();
      stopwatch.stop();
      return ServerQuality(
        config: config,
        ping: stopwatch.elapsedMilliseconds,
        remark: uri.fragment.isNotEmpty ? uri.fragment : host,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _connectToServer(ServerQuality server) async {
    if (_deadConfigs.contains(server.config)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Этот сервер ранее не работал, пробую другой...')),
      );
      _handleConnectionError();
      return;
    }

    print('▶️ Попытка подключения к ${server.remark}');
    if (_isConnected) {
      await _disconnect();
    }

    try {
      final FlutterV2RayURL parser = FlutterV2ray.parseFromURL(server.config);
      if (parser == null) {
        print('❌ Ошибка парсинга конфига');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Неверный формат конфига')),
        );
        return;
      }
      print('✅ Парсинг успешен, remark: ${parser.remark}');

      final bool allowed = await _flutterV2Ray.requestPermission();
      if (!allowed) {
        print('❌ Нет разрешения на VPN');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Нет разрешения на VPN')),
        );
        return;
      }
      print('✅ Разрешение получено');

      setState(() {
        _currentServer = server;
        _status = 'Подключаюсь...';
      });

      await _flutterV2Ray.startVless(
        remark: parser.remark ?? server.remark,
        config: parser.getFullConfiguration(),
        proxyOnly: false,
      );
      print('✅ V2Ray запущен, ждём статуса...');
    } catch (e, stack) {
      print('‼️ Ошибка подключения: $e');
      print(stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка подключения: $e')),
      );
      setState(() {
        _status = 'Ошибка подключения';
      });
      _handleConnectionError();
    }
  }

  Future<void> _disconnect() async {
    try {
      await _flutterV2Ray.stopVless();
      // Состояние обновится через onStatusChanged
    } catch (e) {
      print('Ошибка отключения: $e');
      setState(() {
        _isConnected = false;
        _currentServer = null;
        _status = 'Отключено';
      });
    }
  }

  void _switchToNextServer() {
    if (_servers.isEmpty) return;
    int currentIndex = 0;
    if (_currentServer != null) {
      currentIndex = _servers.indexWhere((s) => s.config == _currentServer!.config);
      if (currentIndex == -1) currentIndex = 0;
    }
    int nextIndex = (currentIndex + 1) % _servers.length;
    int attempts = 0;
    while (_deadConfigs.contains(_servers[nextIndex].config) && attempts < _servers.length) {
      nextIndex = (nextIndex + 1) % _servers.length;
      attempts++;
    }
    _connectToServer(_servers[nextIndex]);
  }

  @override
  void dispose() {
    _flutterV2Ray.stopVless(); // на всякий случай при выходе
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modeTitle),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_isConnected)
            IconButton(
              icon: Icon(Icons.swap_horiz, color: Colors.redAccent),
              tooltip: 'Переключить сервер',
              onPressed: _switchToNextServer,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isConnected) ...[
                  GestureDetector(
                    onTap: _isLoading ? null : _loadConfigs,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Text('💀', style: TextStyle(fontSize: 50)),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    _status,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    ),
                  if (_servers.isNotEmpty && !_isLoading) ...[
                    SizedBox(height: 20),
                    Text(
                      'Доступные серверы:',
                      style: TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                    SizedBox(height: 5),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _servers.length,
                        itemBuilder: (context, index) {
                          final s = _servers[index];
                          final isCurrent = _currentServer == s;
                          final isDead = _deadConfigs.contains(s.config);
                          if (isDead) return SizedBox.shrink();
                          return Card(
                            color: isCurrent ? Colors.redAccent.withOpacity(0.2) : Colors.black54,
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(Icons.wifi, color: isCurrent ? Colors.greenAccent : Colors.redAccent, size: 20),
                              title: Text(
                                s.remark,
                                style: TextStyle(
                                  color: isCurrent ? Colors.greenAccent : Colors.white,
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Пинг: ${s.ping} мс',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                              ),
                              onTap: () => _connectToServer(s),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ] else ...[
                  // Состояние ПОДКЛЮЧЕНО
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.greenAccent, width: 3),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Text('💀', style: TextStyle(fontSize: 50)),
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    '✅ ПОДКЛЮЧЕНО',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    _currentServer?.remark ?? '',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Пинг: ${_currentServer?.ping ?? 0} мс',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (_status.contains('YouTube')) ...[
                    SizedBox(height: 5),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _status.startsWith('✅') ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  SizedBox(height: 30),

                  // КНОПКА ОТКЛЮЧЕНИЯ (большая и красная)
                  ElevatedButton(
                    onPressed: _disconnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '🔴 ОТКЛЮЧИТЬСЯ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (_servers.length > 1)
                    TextButton(
                      onPressed: _switchToNextServer,
                      child: Text(
                        'Переключить на другой сервер',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 14),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ServerQuality {
  final String config;
  final int ping;
  final String remark;
  ServerQuality({required this.config, required this.ping, required this.remark});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerQuality && runtimeType == other.runtimeType && config == other.config;

  @override
  int get hashCode => config.hashCode;
}