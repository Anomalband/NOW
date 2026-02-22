import "dart:convert";

import "package:http/http.dart" as http;

class NowApiException implements Exception {
  const NowApiException(this.message);

  final String message;

  @override
  String toString() => "NowApiException: $message";
}

class ApiHealth {
  const ApiHealth({
    required this.ok,
    required this.service,
    required this.timestamp,
  });

  final bool ok;
  final String service;
  final DateTime timestamp;
}

class NowUser {
  const NowUser({
    required this.id,
    required this.displayName,
    required this.age,
    required this.city,
    required this.karma,
  });

  final String id;
  final String displayName;
  final int age;
  final String city;
  final int karma;
}

class NowQuest {
  const NowQuest({
    required this.id,
    required this.title,
    required this.district,
    required this.active,
  });

  final String id;
  final String title;
  final String district;
  final bool active;
}

class NowQuestSummary {
  const NowQuestSummary({
    required this.id,
    required this.title,
    required this.district,
  });

  final String id;
  final String title;
  final String district;
}

class NowMatchUser {
  const NowMatchUser({
    required this.id,
    required this.displayName,
    required this.age,
    required this.city,
    required this.karma,
  });

  final String id;
  final String displayName;
  final int age;
  final String city;
  final int karma;
}

class NowMatchMessage {
  const NowMatchMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

class NowMatchProofState {
  const NowMatchProofState({
    required this.mineUrl,
    required this.partnerUrl,
    required this.mineSubmittedAt,
    required this.partnerSubmittedAt,
  });

  final String? mineUrl;
  final String? partnerUrl;
  final DateTime? mineSubmittedAt;
  final DateTime? partnerSubmittedAt;
}

class NowMatchConfirmationState {
  const NowMatchConfirmationState({
    required this.mineAt,
    required this.partnerAt,
  });

  final DateTime? mineAt;
  final DateTime? partnerAt;
}

class NowMatchSummary {
  const NowMatchSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.completedAt,
    required this.quest,
    required this.partner,
    required this.proof,
    required this.confirmation,
    this.lastMessage,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final NowQuestSummary quest;
  final NowMatchUser partner;
  final NowMatchProofState proof;
  final NowMatchConfirmationState confirmation;
  final NowMatchMessage? lastMessage;

  bool get isCompleted => status.toUpperCase() == "COMPLETED";
}

class NowFindMatchResult {
  const NowFindMatchResult({
    required this.created,
    required this.matched,
    required this.match,
    this.message,
  });

  final bool created;
  final bool matched;
  final NowMatchSummary? match;
  final String? message;
}

class NowKarmaEvent {
  const NowKarmaEvent({
    required this.id,
    required this.delta,
    required this.reason,
    required this.matchId,
    required this.createdAt,
  });

  final String id;
  final int delta;
  final String reason;
  final String? matchId;
  final DateTime createdAt;
}

class NowKarmaHistory {
  const NowKarmaHistory({required this.karma, required this.events});

  final int karma;
  final List<NowKarmaEvent> events;
}

class NowApiClient {
  NowApiClient(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<ApiHealth> checkHealth() async {
    final data = await _request(method: "GET", path: "/health");

    return ApiHealth(
      ok: data["ok"] == true,
      service: (data["service"] ?? "").toString(),
      timestamp:
          DateTime.tryParse((data["timestamp"] ?? "").toString()) ??
          DateTime.now(),
    );
  }

  Future<NowUser> createUser({
    required String displayName,
    required int age,
    required String city,
  }) async {
    final data = await _request(
      method: "POST",
      path: "/users",
      body: {"displayName": displayName, "age": age, "city": city},
    );

    return NowUser(
      id: (data["id"] ?? "").toString(),
      displayName: (data["displayName"] ?? "").toString(),
      age: (data["age"] as num?)?.toInt() ?? 0,
      city: (data["city"] ?? "").toString(),
      karma: (data["karma"] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> upsertDailyProfile({
    required String userId,
    required String district,
    required String photoUrl,
    String? mood,
  }) async {
    await _request(
      method: "POST",
      path: "/daily-profiles",
      body: {
        "userId": userId,
        "district": district,
        "photoUrl": photoUrl,
        if (mood != null && mood.isNotEmpty) "mood": mood,
      },
    );
  }

  Future<List<NowQuest>> listQuests({
    required String district,
    int limit = 25,
  }) async {
    final data = await _request(
      method: "GET",
      path: "/quests?district=${Uri.encodeComponent(district)}&limit=$limit",
    );

    final rawList = data["data"];
    if (rawList is! List) {
      return const [];
    }

    return rawList.map((rawItem) {
      final item = rawItem as Map<String, dynamic>;
      return NowQuest(
        id: (item["id"] ?? "").toString(),
        title: (item["title"] ?? "").toString(),
        district: (item["district"] ?? "").toString(),
        active: item["active"] == true,
      );
    }).toList();
  }

  Future<void> selectQuest({
    required String userId,
    required String questId,
  }) async {
    await _request(
      method: "POST",
      path: "/quest-selections",
      body: {"userId": userId, "questId": questId},
    );
  }

  Future<NowFindMatchResult> findOrCreateMatch({required String userId}) async {
    final data = await _request(
      method: "POST",
      path: "/matches/find-or-create",
      body: {"userId": userId},
    );

    final matchRaw = data["data"];
    NowMatchSummary? match;
    if (matchRaw is Map<String, dynamic>) {
      match = _parseMatchFromRaw(matchRaw, userId);
    }

    return NowFindMatchResult(
      created: data["created"] == true,
      matched: data["matched"] == true,
      match: match,
      message: data["message"]?.toString(),
    );
  }

  Future<List<NowMatchSummary>> listMatches({
    required String userId,
    int limit = 20,
  }) async {
    final data = await _request(
      method: "GET",
      path: "/matches?userId=${Uri.encodeComponent(userId)}&limit=$limit",
    );

    final rawList = data["data"];
    if (rawList is! List) {
      return const [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseMatchFromList(item))
        .toList();
  }

  Future<List<NowMatchMessage>> listMatchMessages({
    required String matchId,
    required String userId,
    int limit = 200,
  }) async {
    final data = await _request(
      method: "GET",
      path:
          "/matches/${Uri.encodeComponent(matchId)}/messages?userId=${Uri.encodeComponent(userId)}&limit=$limit",
    );

    final rawList = data["data"];
    if (rawList is! List) {
      return const [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseMessage(item))
        .toList();
  }

  Future<NowMatchMessage> sendMatchMessage({
    required String matchId,
    required String senderId,
    required String content,
  }) async {
    final data = await _request(
      method: "POST",
      path: "/matches/${Uri.encodeComponent(matchId)}/messages",
      body: {"senderId": senderId, "content": content},
    );

    return _parseMessage(data);
  }

  Future<void> submitMatchProof({
    required String matchId,
    required String userId,
    required String photoUrl,
  }) async {
    await _request(
      method: "POST",
      path: "/matches/${Uri.encodeComponent(matchId)}/proof",
      body: {"userId": userId, "photoUrl": photoUrl},
    );
  }

  Future<void> completeMatch({
    required String matchId,
    required String userId,
  }) async {
    await _request(
      method: "POST",
      path: "/matches/${Uri.encodeComponent(matchId)}/complete",
      body: {"userId": userId},
    );
  }

  Future<NowKarmaHistory> getKarmaHistory({
    required String userId,
    int limit = 50,
  }) async {
    final data = await _request(
      method: "GET",
      path: "/users/${Uri.encodeComponent(userId)}/karma-history?limit=$limit",
    );

    final eventsRaw = data["data"];
    final events = eventsRaw is List
        ? eventsRaw
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => NowKarmaEvent(
                  id: (item["id"] ?? "").toString(),
                  delta: (item["delta"] as num?)?.toInt() ?? 0,
                  reason: (item["reason"] ?? "").toString(),
                  matchId: item["matchId"]?.toString(),
                  createdAt: _parseDate(item["createdAt"]),
                ),
              )
              .toList()
        : const <NowKarmaEvent>[];

    return NowKarmaHistory(
      karma: (data["karma"] as num?)?.toInt() ?? 0,
      events: events,
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse("$baseUrl$path");

    late http.Response response;
    try {
      if (method == "GET") {
        response = await _client.get(uri, headers: _headers());
      } else if (method == "POST") {
        response = await _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode(body ?? <String, dynamic>{}),
        );
      } else {
        throw const NowApiException("Unsupported HTTP method.");
      }
    } catch (error) {
      throw NowApiException("API baglantisi kurulamadi: $error");
    }

    final payload = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    final apiMessage = payload["error"]?.toString() ?? "Bilinmeyen API hatasi";
    throw NowApiException("$apiMessage (HTTP ${response.statusCode})");
  }

  static Map<String, String> _headers() {
    return const {"content-type": "application/json"};
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    final parsed = jsonDecode(body);
    if (parsed is Map<String, dynamic>) {
      return parsed;
    }
    return <String, dynamic>{};
  }

  static NowMatchSummary _parseMatchFromList(Map<String, dynamic> item) {
    final questRaw = _asMap(item["quest"]);
    final partnerRaw = _asMap(item["partner"]);
    final proofRaw = _asMap(item["proof"]);
    final confirmationRaw = _asMap(item["confirmation"]);
    final lastMessageRaw = _asMap(item["lastMessage"]);

    return NowMatchSummary(
      id: (item["id"] ?? "").toString(),
      status: (item["status"] ?? "").toString(),
      createdAt: _parseDate(item["createdAt"]),
      expiresAt: _parseDate(item["expiresAt"]),
      completedAt: _parseNullableDate(item["completedAt"]),
      quest: _parseQuestSummary(questRaw),
      partner: _parseMatchUser(partnerRaw),
      proof: NowMatchProofState(
        mineUrl: proofRaw["mine"]?.toString(),
        partnerUrl: proofRaw["partner"]?.toString(),
        mineSubmittedAt: _parseNullableDate(proofRaw["mineSubmittedAt"]),
        partnerSubmittedAt: _parseNullableDate(proofRaw["partnerSubmittedAt"]),
      ),
      confirmation: NowMatchConfirmationState(
        mineAt: _parseNullableDate(confirmationRaw["mine"]),
        partnerAt: _parseNullableDate(confirmationRaw["partner"]),
      ),
      lastMessage: lastMessageRaw.isEmpty
          ? null
          : _parseMessage(lastMessageRaw),
    );
  }

  static NowMatchSummary _parseMatchFromRaw(
    Map<String, dynamic> item,
    String viewerUserId,
  ) {
    final userAId = (item["userAId"] ?? "").toString();

    final isUserA = userAId == viewerUserId;
    final partnerRaw = isUserA ? _asMap(item["userB"]) : _asMap(item["userA"]);

    return NowMatchSummary(
      id: (item["id"] ?? "").toString(),
      status: (item["status"] ?? "").toString(),
      createdAt: _parseDate(item["createdAt"]),
      expiresAt: _parseDate(item["expiresAt"]),
      completedAt: _parseNullableDate(item["completedAt"]),
      quest: _parseQuestSummary(_asMap(item["quest"])),
      partner: _parseMatchUser(partnerRaw),
      proof: NowMatchProofState(
        mineUrl: isUserA
            ? item["proofPhotoA"]?.toString()
            : item["proofPhotoB"]?.toString(),
        partnerUrl: isUserA
            ? item["proofPhotoB"]?.toString()
            : item["proofPhotoA"]?.toString(),
        mineSubmittedAt: _parseNullableDate(
          isUserA ? item["proofSubmittedAAt"] : item["proofSubmittedBAt"],
        ),
        partnerSubmittedAt: _parseNullableDate(
          isUserA ? item["proofSubmittedBAt"] : item["proofSubmittedAAt"],
        ),
      ),
      confirmation: NowMatchConfirmationState(
        mineAt: _parseNullableDate(
          isUserA ? item["confirmedByAAt"] : item["confirmedByBAt"],
        ),
        partnerAt: _parseNullableDate(
          isUserA ? item["confirmedByBAt"] : item["confirmedByAAt"],
        ),
      ),
      lastMessage: null,
    );
  }

  static NowQuestSummary _parseQuestSummary(Map<String, dynamic> item) {
    return NowQuestSummary(
      id: (item["id"] ?? "").toString(),
      title: (item["title"] ?? "").toString(),
      district: (item["district"] ?? "").toString(),
    );
  }

  static NowMatchUser _parseMatchUser(Map<String, dynamic> item) {
    return NowMatchUser(
      id: (item["id"] ?? "").toString(),
      displayName: (item["displayName"] ?? "").toString(),
      age: (item["age"] as num?)?.toInt() ?? 0,
      city: (item["city"] ?? "").toString(),
      karma: (item["karma"] as num?)?.toInt() ?? 0,
    );
  }

  static NowMatchMessage _parseMessage(Map<String, dynamic> item) {
    return NowMatchMessage(
      id: (item["id"] ?? "").toString(),
      senderId: (item["senderId"] ?? "").toString(),
      content: (item["content"] ?? "").toString(),
      createdAt: _parseDate(item["createdAt"]),
      expiresAt: _parseNullableDate(item["expiresAt"]),
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return <String, dynamic>{};
  }

  static DateTime _parseDate(Object? value) {
    final raw = value?.toString() ?? "";
    return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now().toLocal();
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) {
      return null;
    }
    final raw = value.toString();
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }
}
