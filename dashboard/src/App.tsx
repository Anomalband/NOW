import { useMemo, useState } from "react";
import "./App.css";

type HealthResponse = {
  ok: boolean;
  service: string;
  timestamp: string;
};

type Quest = {
  id: string;
  title: string;
  district: string;
  active: boolean;
};

type QuestResponse = {
  count: number;
  data: Quest[];
};

type UserResponse = {
  id: string;
  displayName: string;
  age: number;
  city: string;
  karma: number;
};

type MatchUser = {
  id: string;
  displayName: string;
  age: number;
  city: string;
  karma: number;
};

type MatchItem = {
  id: string;
  status: string;
  createdAt: string;
  expiresAt: string;
  completedAt: string | null;
  quest: {
    id: string;
    title: string;
    district: string;
  };
  partner: MatchUser;
  proof: {
    mine: string | null;
    partner: string | null;
    mineSubmittedAt: string | null;
    partnerSubmittedAt: string | null;
  };
  confirmation: {
    mine: string | null;
    partner: string | null;
  };
  lastMessage: {
    id: string;
    senderId: string;
    content: string;
    createdAt: string;
  } | null;
};

type MatchListResponse = {
  count: number;
  data: MatchItem[];
};

type MessageItem = {
  id: string;
  senderId: string;
  content: string;
  createdAt: string;
  expiresAt: string;
};

type MessageListResponse = {
  count: number;
  data: MessageItem[];
};

type KarmaEvent = {
  id: string;
  delta: number;
  reason: string;
  matchId: string | null;
  createdAt: string;
};

type KarmaHistoryResponse = {
  karma: number;
  count: number;
  data: KarmaEvent[];
};

const defaultApiBaseUrl =
  import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1";

function App() {
  const [apiBaseUrl, setApiBaseUrl] = useState(defaultApiBaseUrl);
  const [district, setDistrict] = useState("Kadikoy");
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [quests, setQuests] = useState<Quest[]>([]);
  const [selectedQuestId, setSelectedQuestId] = useState("");

  const [displayName, setDisplayName] = useState("Now User");
  const [age, setAge] = useState("24");
  const [city, setCity] = useState("Istanbul");
  const [userId, setUserId] = useState("");
  const [userKarma, setUserKarma] = useState(0);

  const [matches, setMatches] = useState<MatchItem[]>([]);
  const [activeMatchId, setActiveMatchId] = useState("");
  const [messages, setMessages] = useState<MessageItem[]>([]);
  const [messageText, setMessageText] = useState("");
  const [proofUrl, setProofUrl] = useState("");
  const [dailyPhotoUrl, setDailyPhotoUrl] = useState(
    "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/",
  );
  const [dailyMood, setDailyMood] = useState("ready");
  const [karmaEvents, setKarmaEvents] = useState<KarmaEvent[]>([]);

  const [adminToken, setAdminToken] = useState("");
  const [statusText, setStatusText] = useState("Ready");
  const [loading, setLoading] = useState(false);

  const prettyApiBaseUrl = useMemo(
    () => apiBaseUrl.replace(/\/$/, ""),
    [apiBaseUrl],
  );

  const activeMatch =
    matches.find((match) => match.id === activeMatchId) ?? null;

  async function callApi<T>(path: string, init?: RequestInit): Promise<T> {
    const response = await fetch(`${prettyApiBaseUrl}${path}`, init);
    const data = (await response.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;

    if (!response.ok) {
      const apiError =
        typeof data.error === "string"
          ? data.error
          : `Request failed (${response.status})`;
      throw new Error(apiError);
    }

    return data as T;
  }

  async function checkHealth() {
    setLoading(true);
    setStatusText("Checking API health...");
    try {
      const data = await callApi<HealthResponse>("/health");
      setHealth(data);
      setStatusText("Health check OK");
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Health failed");
    } finally {
      setLoading(false);
    }
  }

  async function createUser() {
    if (displayName.trim().length < 2) {
      setStatusText("Display name en az 2 karakter olmali.");
      return;
    }
    const parsedAge = Number(age);
    if (!Number.isFinite(parsedAge)) {
      setStatusText("Yas sayi olmali.");
      return;
    }

    setLoading(true);
    setStatusText("Creating user...");
    try {
      const data = await callApi<UserResponse>("/users", {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          displayName: displayName.trim(),
          age: parsedAge,
          city: city.trim(),
        }),
      });

      setUserId(data.id);
      setUserKarma(data.karma);
      setStatusText(`User created: ${data.displayName}`);
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "User create failed");
    } finally {
      setLoading(false);
    }
  }

  async function loadQuests() {
    setLoading(true);
    setStatusText("Loading quests...");
    try {
      const data = await callApi<QuestResponse>(
        `/quests?district=${encodeURIComponent(district)}&limit=25`,
      );
      setQuests(data.data);
      setStatusText(`Loaded ${data.count} quests`);
      if (data.data.length > 0) {
        setSelectedQuestId((current) => current || data.data[0].id);
      }
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Quest load failed");
    } finally {
      setLoading(false);
    }
  }

  async function selectQuest() {
    if (!userId) {
      setStatusText("Once user olustur.");
      return;
    }
    if (!selectedQuestId) {
      setStatusText("Bir quest sec.");
      return;
    }

    setLoading(true);
    setStatusText("Saving quest selection...");
    try {
      await callApi("/quest-selections", {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          userId,
          questId: selectedQuestId,
        }),
      });
      setStatusText("Quest selection saved.");
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Quest selection failed");
    } finally {
      setLoading(false);
    }
  }

  async function publishDailyProfile() {
    if (!userId) {
      setStatusText("Once user olustur.");
      return;
    }
    if (!dailyPhotoUrl.trim()) {
      setStatusText("Daily profile photo gerekli.");
      return;
    }

    setLoading(true);
    setStatusText("Publishing daily profile...");
    try {
      await callApi("/daily-profiles", {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          userId,
          district: district.trim(),
          photoUrl: dailyPhotoUrl.trim(),
          mood: dailyMood.trim(),
        }),
      });
      setStatusText("Daily profile published.");
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Daily profile failed");
    } finally {
      setLoading(false);
    }
  }

  async function refreshMatchesInternal(currentUserId: string) {
    const data = await callApi<MatchListResponse>(
      `/matches?userId=${encodeURIComponent(currentUserId)}&limit=25`,
    );
    setMatches(data.data);
    const nextActiveId =
      data.data.find((item) => item.id === activeMatchId)?.id ??
      data.data[0]?.id ??
      "";
    setActiveMatchId(nextActiveId);
    return nextActiveId;
  }

  async function findOrCreateMatch() {
    if (!userId) {
      setStatusText("Once user olustur.");
      return;
    }
    setLoading(true);
    setStatusText("Searching match...");
    try {
      const result = await callApi<{ created: boolean; matched: boolean; message?: string }>(
        "/matches/find-or-create",
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
          },
          body: JSON.stringify({ userId }),
        },
      );
      await refreshMatchesInternal(userId);
      if (result.matched) {
        setStatusText(result.created ? "New match created." : "Active match already exists.");
      } else {
        setStatusText(result.message ?? "No candidate found yet.");
      }
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Match search failed");
    } finally {
      setLoading(false);
    }
  }

  async function loadMatches() {
    if (!userId) {
      setStatusText("Once user olustur.");
      return;
    }
    setLoading(true);
    setStatusText("Loading matches...");
    try {
      await refreshMatchesInternal(userId);
      setStatusText("Matches loaded.");
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Match load failed");
    } finally {
      setLoading(false);
    }
  }

  async function loadMessages(matchIdOverride?: string) {
    if (!userId) {
      setStatusText("Once user olustur.");
      return;
    }
    const targetMatchId = matchIdOverride ?? activeMatchId;
    if (!targetMatchId) {
      setStatusText("Bir match sec.");
      return;
    }
    setLoading(true);
    setStatusText("Loading messages...");
    try {
      const data = await callApi<MessageListResponse>(
        `/matches/${encodeURIComponent(targetMatchId)}/messages?userId=${encodeURIComponent(userId)}&limit=200`,
      );
      setMessages(data.data);
      setStatusText(`${data.count} messages loaded.`);
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Message load failed");
    } finally {
      setLoading(false);
    }
  }

  async function sendMessage() {
    if (!userId || !activeMatchId) {
      setStatusText("User ve match secili olmali.");
      return;
    }
    if (!messageText.trim()) {
      setStatusText("Mesaj bos olamaz.");
      return;
    }

    setLoading(true);
    setStatusText("Sending message...");
    try {
      await callApi(`/matches/${encodeURIComponent(activeMatchId)}/messages`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          senderId: userId,
          content: messageText.trim(),
        }),
      });
      setMessageText("");
      await loadMessages(activeMatchId);
      await refreshMatchesInternal(userId);
      setStatusText("Message sent.");
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Message send failed");
    } finally {
      setLoading(false);
    }
  }

  async function submitProof() {
    if (!userId || !activeMatchId) {
      setStatusText("User ve match secili olmali.");
      return;
    }
    if (!proofUrl.trim()) {
      setStatusText("Proof URL gerekli.");
      return;
    }

    setLoading(true);
    setStatusText("Submitting proof...");
    try {
      await callApi(`/matches/${encodeURIComponent(activeMatchId)}/proof`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({
          userId,
          photoUrl: proofUrl.trim(),
        }),
      });
      await refreshMatchesInternal(userId);
      setStatusText("Proof submitted.");
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Proof submit failed");
    } finally {
      setLoading(false);
    }
  }

  async function completeMatch() {
    if (!userId || !activeMatchId) {
      setStatusText("User ve match secili olmali.");
      return;
    }
    setLoading(true);
    setStatusText("Completing match...");
    try {
      await callApi(`/matches/${encodeURIComponent(activeMatchId)}/complete`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify({ userId }),
      });
      await refreshMatchesInternal(userId);
      await loadKarmaHistory();
      setStatusText("Completion confirmation sent.");
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Complete failed");
    } finally {
      setLoading(false);
    }
  }

  async function loadKarmaHistory() {
    if (!userId) {
      setStatusText("Once user olustur.");
      return;
    }
    setLoading(true);
    setStatusText("Loading karma history...");
    try {
      const data = await callApi<KarmaHistoryResponse>(
        `/users/${encodeURIComponent(userId)}/karma-history?limit=20`,
      );
      setUserKarma(data.karma);
      setKarmaEvents(data.data);
      setStatusText(`Karma updated: ${data.karma}`);
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Karma load failed");
    } finally {
      setLoading(false);
    }
  }

  async function runCleanupDryRun() {
    setLoading(true);
    setStatusText("Running cleanup dry-run...");
    try {
      const data = await callApi<{
        expiredMessages: number;
        expiredMatches: number;
        expiredSelections: number;
        expiredProfiles: number;
      }>("/admin/cleanup?dryRun=true", {
        method: "POST",
        headers: {
          "x-admin-token": adminToken,
        },
      });
      setStatusText(
        `Dry-run -> messages:${data.expiredMessages}, matches:${data.expiredMatches}, selections:${data.expiredSelections}, profiles:${data.expiredProfiles}`,
      );
    } catch (error) {
      setStatusText(error instanceof Error ? error.message : "Cleanup failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="panel">
      <section className="hero">
        <p className="eyebrow">NOW CONTROL SURFACE</p>
        <h1>Real-time social flow burada yonetilir.</h1>
        <p className="subtitle">
          User olustur, daily quest sec, match yarat, chat/proof/completion adimlarini test et ve karma etkisini
          izle.
        </p>
      </section>

      <section className="card">
        <h2>1) API ve User</h2>
        <label htmlFor="apiBaseUrl">API Base URL</label>
        <input
          id="apiBaseUrl"
          value={apiBaseUrl}
          onChange={(event) => setApiBaseUrl(event.target.value)}
          placeholder="https://now-api.onrender.com/api/v1"
        />
        <div className="actions">
          <button type="button" onClick={checkHealth} disabled={loading}>
            Health Check
          </button>
          <span className={health?.ok ? "badge success" : "badge muted"}>
            {health?.ok ? "API Live" : "Not Checked"}
          </span>
        </div>

        <div className="grid3">
          <input value={displayName} onChange={(event) => setDisplayName(event.target.value)} placeholder="Display Name" />
          <input value={age} onChange={(event) => setAge(event.target.value)} placeholder="Age" />
          <input value={city} onChange={(event) => setCity(event.target.value)} placeholder="City" />
        </div>
        <div className="actions">
          <button type="button" onClick={createUser} disabled={loading}>
            Create User
          </button>
        </div>
        <p className="meta">User ID: {userId || "-"}</p>
        <p className="meta">Karma: {userKarma}</p>
      </section>

      <section className="card">
        <h2>2) Daily Profile + Quest + Match</h2>
        <div className="grid2">
          <input
            value={dailyPhotoUrl}
            onChange={(event) => setDailyPhotoUrl(event.target.value)}
            placeholder="Daily profile photo URL veya data:image..."
          />
          <input
            value={dailyMood}
            onChange={(event) => setDailyMood(event.target.value)}
            placeholder="Mood (opsiyonel)"
          />
        </div>
        <div className="grid2">
          <input value={district} onChange={(event) => setDistrict(event.target.value)} placeholder="District" />
          <select value={selectedQuestId} onChange={(event) => setSelectedQuestId(event.target.value)}>
            <option value="">Quest sec</option>
            {quests.map((quest) => (
              <option key={quest.id} value={quest.id}>
                {quest.title}
              </option>
            ))}
          </select>
        </div>
        <div className="actions">
          <button type="button" onClick={publishDailyProfile} disabled={loading || !userId || !dailyPhotoUrl.trim()}>
            Publish Daily Profile
          </button>
          <button type="button" onClick={loadQuests} disabled={loading}>
            Load Quests
          </button>
          <button type="button" onClick={selectQuest} disabled={loading || !selectedQuestId || !userId}>
            Save Quest Selection
          </button>
          <button type="button" onClick={findOrCreateMatch} disabled={loading || !userId}>
            Find / Create Match
          </button>
          <button type="button" onClick={loadMatches} disabled={loading || !userId}>
            Refresh Matches
          </button>
        </div>

        <ul className="matchList">
          {matches.map((match) => (
            <li key={match.id} className={match.id === activeMatchId ? "active" : ""}>
              <button
                type="button"
                className="listButton"
                onClick={async () => {
                  setActiveMatchId(match.id);
                  await loadMessages(match.id);
                }}
              >
                <strong>{match.partner.displayName}</strong>
                <span>
                  {match.quest.title} | {match.status}
                </span>
              </button>
            </li>
          ))}
          {matches.length === 0 && <li className="empty">Aktif match yok.</li>}
        </ul>
      </section>

      <section className="card">
        <h2>3) Chat + Proof + Complete</h2>
        <p className="meta">Active Match: {activeMatch?.id ?? "-"}</p>
        <div className="actions">
          <button type="button" onClick={() => loadMessages()} disabled={loading || !activeMatchId || !userId}>
            Load Messages
          </button>
        </div>
        <div className="chatBox">
          {messages.map((message) => (
            <article key={message.id}>
              <strong>{message.senderId === userId ? "Me" : message.senderId}</strong>
              <p>{message.content}</p>
            </article>
          ))}
          {messages.length === 0 && <p className="empty">Mesaj yok.</p>}
        </div>
        <div className="grid2">
          <input
            value={messageText}
            onChange={(event) => setMessageText(event.target.value)}
            placeholder="Mesaj yaz..."
          />
          <button type="button" onClick={sendMessage} disabled={loading || !userId || !activeMatchId}>
            Send Message
          </button>
        </div>
        <div className="grid2">
          <input
            value={proofUrl}
            onChange={(event) => setProofUrl(event.target.value)}
            placeholder="Proof photo URL veya data:image..."
          />
          <button type="button" onClick={submitProof} disabled={loading || !userId || !activeMatchId}>
            Submit Proof
          </button>
        </div>
        <div className="actions">
          <button type="button" onClick={completeMatch} disabled={loading || !userId || !activeMatchId}>
            Complete Match
          </button>
        </div>
      </section>

      <section className="card">
        <h2>4) Karma + Cleanup</h2>
        <div className="actions">
          <button type="button" onClick={loadKarmaHistory} disabled={loading || !userId}>
            Load Karma History
          </button>
        </div>
        <ul className="eventList">
          {karmaEvents.map((event) => (
            <li key={event.id}>
              <strong>{event.delta >= 0 ? `+${event.delta}` : event.delta}</strong>
              <span>{event.reason}</span>
            </li>
          ))}
          {karmaEvents.length === 0 && <li className="empty">Karma event yok.</li>}
        </ul>

        <label htmlFor="token">Admin Token</label>
        <input
          id="token"
          value={adminToken}
          onChange={(event) => setAdminToken(event.target.value)}
          placeholder="x-admin-token"
          type="password"
        />
        <div className="actions">
          <button type="button" onClick={runCleanupDryRun} disabled={loading || adminToken.length < 12}>
            Cleanup Dry-Run
          </button>
        </div>
      </section>

      <footer className="statusBar">{statusText}</footer>
    </main>
  );
}

export default App;
