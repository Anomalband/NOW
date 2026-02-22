import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:camera/camera.dart";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../core/time_utils.dart";
import "../../data/now_api_client.dart";
import "camera_capture_screen.dart";

class NowHomeScreen extends StatefulWidget {
  const NowHomeScreen({super.key});

  @override
  State<NowHomeScreen> createState() => _NowHomeScreenState();
}

class _NowHomeScreenState extends State<NowHomeScreen> {
  static const _defaultApiBaseUrl = "http://10.0.2.2:3000/api/v1";
  static const _prefsApiBaseUrl = "now_api_base_url";
  static const _prefsUserId = "now_user_id";
  static const _prefsDisplayName = "now_display_name";
  static const _prefsAge = "now_age";
  static const _prefsCity = "now_city";
  static const _prefsDistrict = "now_district";
  static const _districts = [
    "Kadikoy",
    "Besiktas",
    "Beyoglu",
    "Sisli",
    "Uskudar",
  ];

  final _apiBaseUrlController = TextEditingController(text: _defaultApiBaseUrl);
  final _displayNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController(text: "Istanbul");
  final _moodController = TextEditingController();
  final _chatController = TextEditingController();

  List<CameraDescription> _cameras = const [];
  List<NowQuest> _quests = const [];
  List<NowMatchSummary> _matches = const [];
  List<NowMatchMessage> _messages = const [];
  List<NowKarmaEvent> _karmaEvents = const [];
  String _district = _districts.first;

  String? _userId;
  String? _selectedQuestId;
  String? _selectedQuestTitle;
  String? _activeMatchId;
  int _karma = 0;

  Uint8List? _photoBytes;
  String? _photoDataUri;
  Uint8List? _proofBytes;
  String? _proofDataUri;

  bool _isBusy = false;
  bool _apiLive = false;
  DateTime? _healthTimestamp;
  String _statusText = "Ready";
  Duration _remaining = remainingUntilIstanbulMidnight(DateTime.now());
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _hydrateState();
    _loadCameras();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _remaining = remainingUntilIstanbulMidnight(DateTime.now());
      });
    });
  }

  Future<void> _hydrateState() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedApiBaseUrl = prefs.getString(_prefsApiBaseUrl);
    final cachedUserId = prefs.getString(_prefsUserId);
    final cachedName = prefs.getString(_prefsDisplayName);
    final cachedAge = prefs.getInt(_prefsAge);
    final cachedCity = prefs.getString(_prefsCity);
    final cachedDistrict = prefs.getString(_prefsDistrict);

    if (!mounted) {
      return;
    }

    setState(() {
      if (cachedApiBaseUrl != null && cachedApiBaseUrl.isNotEmpty) {
        _apiBaseUrlController.text = cachedApiBaseUrl;
      }
      if (cachedName != null) {
        _displayNameController.text = cachedName;
      }
      if (cachedAge != null) {
        _ageController.text = cachedAge.toString();
      }
      if (cachedCity != null && cachedCity.isNotEmpty) {
        _cityController.text = cachedCity;
      }
      if (cachedDistrict != null &&
          cachedDistrict.isNotEmpty &&
          _districts.contains(cachedDistrict)) {
        _district = cachedDistrict;
      }
      _userId = cachedUserId;
    });

    if (cachedUserId != null && cachedUserId.isNotEmpty) {
      unawaited(_silentInitialSync(cachedUserId));
    }
  }

  Future<void> _silentInitialSync(String userId) async {
    try {
      final api = _api();
      final health = await api.checkHealth();
      final matches = await api.listMatches(userId: userId, limit: 30);
      final karmaHistory = await api.getKarmaHistory(userId: userId, limit: 10);

      String? activeMatchId = _activeMatchId;
      if (matches.isEmpty) {
        activeMatchId = null;
      } else if (activeMatchId == null ||
          !matches.any((match) => match.id == activeMatchId)) {
        activeMatchId = matches.first.id;
      }

      List<NowMatchMessage> messages = const [];
      if (activeMatchId != null) {
        messages = await api.listMatchMessages(
          matchId: activeMatchId,
          userId: userId,
          limit: 250,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _apiLive = health.ok;
        _healthTimestamp = health.timestamp;
        _matches = matches;
        _activeMatchId = activeMatchId;
        _messages = messages;
        _karma = karmaHistory.karma;
        _karmaEvents = karmaHistory.events;
        _statusText = "Kayitli oturum yuklendi.";
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "Kayitli oturum bulundu, veri yeniden yuklenemedi.";
      });
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsApiBaseUrl, _apiBaseUrlController.text.trim());
    await prefs.setString(
      _prefsDisplayName,
      _displayNameController.text.trim(),
    );
    await prefs.setString(_prefsCity, _cityController.text.trim());
    await prefs.setString(_prefsDistrict, _district);

    final parsedAge = int.tryParse(_ageController.text.trim());
    if (parsedAge != null) {
      await prefs.setInt(_prefsAge, parsedAge);
    }

    if (_userId != null) {
      await prefs.setString(_prefsUserId, _userId!);
    }
  }

  Future<void> _loadCameras() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }
      setState(() {
        _cameras = cameras;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "Kamera algilanamadi. Uygulama yine de devam eder.";
      });
    }
  }

  NowApiClient _api() {
    final normalized = _apiBaseUrlController.text.trim().replaceFirst(
      RegExp(r"/$"),
      "",
    );
    return NowApiClient(normalized);
  }

  String _requireUserId() {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw const NowApiException("Once kayit olustur.");
    }
    return userId;
  }

  NowMatchSummary _requireActiveMatch() {
    final active = _activeMatch;
    if (active == null) {
      throw const NowApiException("Aktif bir eslesme secilmedi.");
    }
    return active;
  }

  Future<void> _runTask(
    String runningMessage,
    Future<void> Function() task,
  ) async {
    if (_isBusy) {
      return;
    }

    await _saveDraft();
    setState(() {
      _isBusy = true;
      _statusText = runningMessage;
    });

    try {
      await task();
    } on NowApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "Beklenmeyen hata: $error";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _refreshMatchesInternal(
    String userId, {
    bool refreshMessages = true,
  }) async {
    final api = _api();
    final matches = await api.listMatches(userId: userId, limit: 30);

    String? activeMatchId = _activeMatchId;
    if (matches.isEmpty) {
      activeMatchId = null;
    } else if (activeMatchId == null ||
        !matches.any((match) => match.id == activeMatchId)) {
      activeMatchId = matches.first.id;
    }

    List<NowMatchMessage> messages = _messages;
    if (refreshMessages) {
      if (activeMatchId == null) {
        messages = const [];
      } else {
        messages = await api.listMatchMessages(
          matchId: activeMatchId,
          userId: userId,
          limit: 250,
        );
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _matches = matches;
      _activeMatchId = activeMatchId;
      if (refreshMessages) {
        _messages = messages;
      }
    });
  }

  Future<void> _refreshKarmaInternal(String userId) async {
    final karmaHistory = await _api().getKarmaHistory(
      userId: userId,
      limit: 12,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _karma = karmaHistory.karma;
      _karmaEvents = karmaHistory.events;
    });
  }

  Future<void> _checkHealth() async {
    await _runTask("API health kontrol ediliyor...", () async {
      final result = await _api().checkHealth();
      if (!mounted) {
        return;
      }
      setState(() {
        _apiLive = result.ok;
        _healthTimestamp = result.timestamp;
        _statusText = "API canli.";
      });
    });
  }

  Future<void> _registerUser() async {
    await _runTask("Kayit olusturuluyor...", () async {
      final displayName = _displayNameController.text.trim();
      final city = _cityController.text.trim();
      final age = int.tryParse(_ageController.text.trim());

      if (displayName.length < 2 || age == null || city.length < 2) {
        throw const NowApiException("Kayit bilgileri eksik veya gecersiz.");
      }

      final user = await _api().createUser(
        displayName: displayName,
        age: age,
        city: city,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsUserId, user.id);

      if (!mounted) {
        return;
      }
      setState(() {
        _userId = user.id;
        _karma = user.karma;
        _statusText = "Kayit tamamlandi: ${user.displayName}";
      });
    });
  }

  Future<void> _capturePhoto({required bool forProof}) async {
    if (_cameras.isEmpty) {
      setState(() {
        _statusText = "Kamera bulunamadi.";
      });
      return;
    }

    final selectedCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        builder: (context) => CameraCaptureScreen(camera: selectedCamera),
      ),
    );

    if (bytes == null || !mounted) {
      return;
    }

    setState(() {
      if (forProof) {
        _proofBytes = bytes;
        _proofDataUri = "data:image/jpeg;base64,${base64Encode(bytes)}";
        _statusText = "Proof fotografi hazir.";
      } else {
        _photoBytes = bytes;
        _photoDataUri = "data:image/jpeg;base64,${base64Encode(bytes)}";
        _statusText = "Gunluk vitrin fotografi hazir.";
      }
    });
  }

  Future<void> _publishDailyProfile() async {
    await _runTask("Gunun vitrini gonderiliyor...", () async {
      final userId = _requireUserId();
      if (_photoDataUri == null) {
        throw const NowApiException("Once kamera ile fotograf cek.");
      }

      await _api().upsertDailyProfile(
        userId: userId,
        district: _district,
        photoUrl: _photoDataUri!,
        mood: _moodController.text.trim(),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "Gunun vitrini aktif.";
      });
    });
  }

  Future<void> _loadQuests() async {
    await _runTask("Gorevler yukleniyor...", () async {
      final quests = await _api().listQuests(district: _district, limit: 25);

      if (!mounted) {
        return;
      }
      setState(() {
        _quests = quests;
        _selectedQuestId = null;
        _selectedQuestTitle = null;
        _statusText = "${quests.length} gorev bulundu.";
      });
    });
  }

  Future<void> _submitQuestSelection() async {
    await _runTask("Gorev secimi kaydediliyor...", () async {
      final userId = _requireUserId();
      if (_selectedQuestId == null) {
        throw const NowApiException("Bir gorev secmeden devam edemezsin.");
      }

      await _api().selectQuest(userId: userId, questId: _selectedQuestId!);

      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "Gunun gorevi secildi.";
      });
    });
  }

  Future<void> _findOrCreateMatch() async {
    await _runTask("Radar taraniyor...", () async {
      final userId = _requireUserId();
      final result = await _api().findOrCreateMatch(userId: userId);

      await _refreshMatchesInternal(userId);
      await _refreshKarmaInternal(userId);

      if (!mounted) {
        return;
      }
      setState(() {
        if (result.matched) {
          _statusText = result.created
              ? "Yeni eslesme bulundu."
              : "Aktif eslesme zaten mevcut.";
        } else {
          _statusText = result.message ?? "Henuz uygun aday bulunmadi.";
        }
      });
    });
  }

  Future<void> _refreshMatches() async {
    await _runTask("Eslesmeler yenileniyor...", () async {
      final userId = _requireUserId();
      await _refreshMatchesInternal(userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "${_matches.length} aktif eslesme listelendi.";
      });
    });
  }

  Future<void> _selectMatch(String matchId) async {
    if (_isBusy) {
      return;
    }
    await _runTask("Mesajlar yukleniyor...", () async {
      final userId = _requireUserId();
      final messages = await _api().listMatchMessages(
        matchId: matchId,
        userId: userId,
        limit: 250,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _activeMatchId = matchId;
        _messages = messages;
        _statusText = "Sohbet hazir.";
      });
    });
  }

  Future<void> _refreshMessages() async {
    await _runTask("Sohbet yenileniyor...", () async {
      final userId = _requireUserId();
      final match = _requireActiveMatch();
      final messages = await _api().listMatchMessages(
        matchId: match.id,
        userId: userId,
        limit: 250,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _messages = messages;
        _statusText = "Mesajlar guncellendi.";
      });
    });
  }

  Future<void> _sendMessage() async {
    await _runTask("Mesaj gonderiliyor...", () async {
      final userId = _requireUserId();
      final match = _requireActiveMatch();
      final content = _chatController.text.trim();

      if (content.isEmpty) {
        throw const NowApiException("Mesaj bos olamaz.");
      }

      await _api().sendMatchMessage(
        matchId: match.id,
        senderId: userId,
        content: content,
      );

      _chatController.clear();
      await _refreshMatchesInternal(userId);

      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "Mesaj gonderildi.";
      });
    });
  }

  Future<void> _submitProof() async {
    await _runTask("Proof gonderiliyor...", () async {
      final userId = _requireUserId();
      final match = _requireActiveMatch();

      if (_proofDataUri == null) {
        throw const NowApiException("Once proof fotografi cek.");
      }

      await _api().submitMatchProof(
        matchId: match.id,
        userId: userId,
        photoUrl: _proofDataUri!,
      );

      await _refreshMatchesInternal(userId);

      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "Proof kaydedildi.";
      });
    });
  }

  Future<void> _completeMatch() async {
    await _runTask("Bulusma tamamlandi onayi gonderiliyor...", () async {
      final userId = _requireUserId();
      final match = _requireActiveMatch();

      await _api().completeMatch(matchId: match.id, userId: userId);
      await _refreshMatchesInternal(userId);
      await _refreshKarmaInternal(userId);

      if (!mounted) {
        return;
      }
      setState(() {
        _statusText =
            "Tamamlama onayi gonderildi. Iki taraf da onaylayinca karma artar.";
      });
    });
  }

  Future<void> _refreshKarma() async {
    await _runTask("Karma gecmisi yenileniyor...", () async {
      final userId = _requireUserId();
      await _refreshKarmaInternal(userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = "Karma gecmisi guncellendi.";
      });
    });
  }

  NowMatchSummary? get _activeMatch {
    final activeMatchId = _activeMatchId;
    if (activeMatchId == null) {
      return null;
    }

    for (final match in _matches) {
      if (match.id == activeMatchId) {
        return match;
      }
    }
    return null;
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case "PENDING":
        return "Beklemede";
      case "ACCEPTED":
        return "Aktif";
      case "COMPLETED":
        return "Tamamlandi";
      case "CANCELLED":
        return "Iptal";
      default:
        return status;
    }
  }

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case "ACCEPTED":
        return const Color(0xFF177A4F);
      case "COMPLETED":
        return const Color(0xFF0D5883);
      case "PENDING":
        return const Color(0xFF8A6A11);
      case "CANCELLED":
        return const Color(0xFF972A1A);
      default:
        return const Color(0xFF3A5360);
    }
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, "0");
    final month = value.month.toString().padLeft(2, "0");
    final hour = value.hour.toString().padLeft(2, "0");
    final minute = value.minute.toString().padLeft(2, "0");
    return "$day.$month $hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    final hasUser = userId != null && userId.isNotEmpty;
    final hasProfilePhoto = _photoDataUri != null;
    final activeMatch = _activeMatch;
    final canQuestActions = hasUser && hasProfilePhoto;
    final canMatchActions = hasUser && _selectedQuestId != null;
    final canChat = hasUser && activeMatch != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7F2F8), Color(0xFFF6EDE5), Color(0xFFDCEAF0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(context),
                const SizedBox(height: 12),
                _buildConnectionCard(context),
                const SizedBox(height: 12),
                _buildRegistrationCard(context),
                const SizedBox(height: 12),
                _buildDailyProfileCard(context, hasUser: hasUser),
                const SizedBox(height: 12),
                _buildQuestCard(context, canQuestActions: canQuestActions),
                const SizedBox(height: 12),
                _buildMatchCard(
                  context,
                  canMatchActions: canMatchActions,
                  hasUser: hasUser,
                ),
                const SizedBox(height: 12),
                _buildChatCard(context, canChat: canChat, userId: userId),
                const SizedBox(height: 12),
                _buildProofAndKarmaCard(
                  context,
                  hasUser: hasUser,
                  activeMatch: activeMatch,
                ),
                const SizedBox(height: 12),
                _buildStatusCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "NOW | 24 Saatlik Sosyallesme",
            style: textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0D3647),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yarin cok gec. En iyi zaman simdi.",
            style: textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF082B38),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(
                avatar: const Icon(Icons.timer_rounded, size: 18),
                label: Text("Kalan: ${formatCountdown(_remaining)}"),
              ),
              Chip(
                avatar: Icon(
                  _apiLive
                      ? Icons.wifi_tethering_rounded
                      : Icons.wifi_off_rounded,
                  size: 18,
                ),
                label: Text(_apiLive ? "API Live" : "API Not Checked"),
              ),
              Chip(
                avatar: const Icon(Icons.bolt_rounded, size: 18),
                label: Text("Karma: $_karma"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Baglanti", style: textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _apiBaseUrlController,
            decoration: const InputDecoration(
              labelText: "API Base URL",
              hintText: "http://10.0.2.2:3000/api/v1",
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isBusy ? null : _checkHealth,
            icon: const Icon(Icons.monitor_heart_rounded),
            label: const Text("Health Check"),
          ),
          if (_healthTimestamp != null) ...[
            const SizedBox(height: 8),
            Text(
              "Son kontrol: ${_formatDate(_healthTimestamp!)}",
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegistrationCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("1) Kayit", style: textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _displayNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: "Isim"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: "Yas"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cityController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: "Sehir"),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isBusy ? null : _registerUser,
            child: const Text("Kayit Ol ve Devam Et"),
          ),
          if (_userId != null) ...[
            const SizedBox(height: 8),
            Text("Aktif kullanici id: $_userId", style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyProfileCard(BuildContext context, {required bool hasUser}) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("2) Gunluk Vitrin", style: textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownMenu<String>(
            width: double.infinity,
            initialSelection: _district,
            enabled: !_isBusy,
            label: const Text("Bolge"),
            dropdownMenuEntries: _districts
                .map(
                  (district) => DropdownMenuEntry<String>(
                    value: district,
                    label: district,
                  ),
                )
                .toList(),
            onSelected: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _district = value;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _moodController,
            decoration: const InputDecoration(
              labelText: "Bugunku mod (opsiyonel)",
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () => _capturePhoto(forProof: false),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text("Kamera Ac"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isBusy || !hasUser ? null : _publishDailyProfile,
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text("Vitrini Yayinla"),
                ),
              ),
            ],
          ),
          if (_photoBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                _photoBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestCard(
    BuildContext context, {
    required bool canQuestActions,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("3) Gunun Gorevi", style: textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isBusy || !canQuestActions ? null : _loadQuests,
                  child: const Text("Gorevleri Yukle"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isBusy || !canQuestActions
                      ? null
                      : _submitQuestSelection,
                  child: const Text("Secimi Kaydet"),
                ),
              ),
            ],
          ),
          if (_quests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              children: _quests.map((quest) {
                final selected = _selectedQuestId == quest.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isBusy
                        ? null
                        : () {
                            setState(() {
                              _selectedQuestId = quest.id;
                              _selectedQuestTitle = quest.title;
                            });
                          },
                    child: Ink(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFE7F1F7)
                            : Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF4A8BA7)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected
                                ? const Color(0xFF1E6C8E)
                                : const Color(0xFF7A8D95),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(quest.title),
                                const SizedBox(height: 2),
                                Text(
                                  quest.district,
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchCard(
    BuildContext context, {
    required bool canMatchActions,
    required bool hasUser,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("4) Radar ve Eslesme", style: textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isBusy || !canMatchActions
                      ? null
                      : _findOrCreateMatch,
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text("Eslesme Ara"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy || !hasUser ? null : _refreshMatches,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Yenile"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_matches.isEmpty)
            const Text("Aktif eslesme yok. Once gorev secip radar tara.")
          else
            Column(
              children: _matches
                  .map(
                    (match) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isBusy ? null : () => _selectMatch(match.id),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: match.id == _activeMatchId
                                ? const Color(0xFFE7F1F7)
                                : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: match.id == _activeMatchId
                                  ? const Color(0xFF4A8BA7)
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            match.partner.displayName,
                                            style: textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${match.partner.age} | ${match.partner.city} | Karma ${match.partner.karma}",
                                            style: textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    _StatusPill(
                                      label: _statusLabel(match.status),
                                      color: _statusColor(match.status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  match.quest.title,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${match.quest.district} | bitis: ${_formatDate(match.expiresAt)}",
                                  style: textTheme.bodySmall,
                                ),
                                if (match.lastMessage != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    "Son mesaj: ${match.lastMessage!.content}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildChatCard(
    BuildContext context, {
    required bool canChat,
    required String? userId,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final activeMatch = _activeMatch;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text("5) Sohbet", style: textTheme.titleLarge)),
              IconButton(
                onPressed: _isBusy || !canChat ? null : _refreshMessages,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: "Mesajlari yenile",
              ),
            ],
          ),
          if (activeMatch == null)
            const Text("Sohbet icin bir eslesme sec.")
          else ...[
            Text(
              "Partner: ${activeMatch.partner.displayName} | Gorev: ${activeMatch.quest.title}",
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: _messages.isEmpty
                  ? const Text("Henuz mesaj yok.")
                  : ListView.builder(
                      itemCount: _messages.length,
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final mine = message.senderId == userId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            constraints: const BoxConstraints(maxWidth: 280),
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xFFE36B3A)
                                  : const Color(0xFFEDF2F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.content,
                                  style: TextStyle(
                                    color: mine
                                        ? Colors.white
                                        : const Color(0xFF1B2E36),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(message.createdAt),
                                  style: TextStyle(
                                    color: mine
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : const Color(0xFF5A6970),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    enabled: !_isBusy,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Mesaj",
                      hintText: "Bulusma icin bir mesaj gonder...",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isBusy ? null : _sendMessage,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text("Gonder"),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProofAndKarmaCard(
    BuildContext context, {
    required bool hasUser,
    required NowMatchSummary? activeMatch,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("6) Proof ve Karma", style: textTheme.titleLarge),
          const SizedBox(height: 8),
          if (activeMatch == null)
            const Text("Proof islemi icin aktif eslesme gerekli.")
          else ...[
            Text(
              "Eslesme: ${activeMatch.partner.displayName} | Durum: ${_statusLabel(activeMatch.status)}",
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  label: activeMatch.proof.mineSubmittedAt == null
                      ? "Ben: Proof yok"
                      : "Ben: Proof var",
                  color: activeMatch.proof.mineSubmittedAt == null
                      ? const Color(0xFF8A6A11)
                      : const Color(0xFF177A4F),
                ),
                _StatusPill(
                  label: activeMatch.proof.partnerSubmittedAt == null
                      ? "Partner: Proof yok"
                      : "Partner: Proof var",
                  color: activeMatch.proof.partnerSubmittedAt == null
                      ? const Color(0xFF8A6A11)
                      : const Color(0xFF177A4F),
                ),
                _StatusPill(
                  label: activeMatch.confirmation.mineAt == null
                      ? "Onayim yok"
                      : "Onay verdim",
                  color: activeMatch.confirmation.mineAt == null
                      ? const Color(0xFF8A6A11)
                      : const Color(0xFF0D5883),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () => _capturePhoto(forProof: true),
                    icon: const Icon(Icons.camera_rounded),
                    label: const Text("Proof Cek"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _submitProof,
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text("Proof Gonder"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isBusy ? null : _completeMatch,
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text("Bulusmayi Tamamla"),
            ),
            if (_proofBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _proofBytes!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text("Karma Gecmisi", style: textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _isBusy || !hasUser ? null : _refreshKarma,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Yenile"),
              ),
            ],
          ),
          if (_karmaEvents.isEmpty)
            const Text("Karma olayi henuz yok.")
          else
            Column(
              children: _karmaEvents
                  .take(6)
                  .map(
                    (event) => Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            event.delta >= 0
                                ? "+${event.delta}"
                                : "${event.delta}",
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: event.delta >= 0
                                  ? const Color(0xFF177A4F)
                                  : const Color(0xFF972A1A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.reason,
                              style: textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            _formatDate(event.createdAt),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFE35E2C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedQuestTitle == null
                  ? "Durum: $_statusText"
                  : "Durum: $_statusText | Secilen gorev: $_selectedQuestTitle",
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _displayNameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _moodController.dispose();
    _chatController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F204B5B),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
