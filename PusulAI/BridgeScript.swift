import Foundation

/// Her sayfa yüklenmeden önce PusulAI'ye enjekte edilen köprü.
/// Site kodunda hiçbir şey değişmez; site kendini "ana ekran uygulaması" sanır ve
/// Notification / titreşim çağrıları iPhone'un yerel bildirimlerine dönüşür.
enum BridgeScript {
    static let source = #"""
(function () {
  if (window.__pusulaiNative) return;

  function post(msg) {
    try { window.webkit.messageHandlers.pusulai.postMessage(msg); } catch (e) {}
  }

  var state = { permission: "__PERMISSION__", reqId: 0, pending: {} };

  var N = {
    isApp: true,
    platform: "ios",
    setPermission: function (p) { state.permission = p; },
    resolvePermission: function (id, p) {
      state.permission = p;
      var cb = state.pending[id];
      delete state.pending[id];
      if (cb) cb(p);
    },
    // Eski sürümdeki sayfa içi sessiz ses kaldırıldı (kilit ekranında müzik oynatıcısı açıyordu);
    // arka plan takibini artık uygulamanın kendisi yapıyor (NativeTracker).
    keepAlive: function () {}
  };
  window.__pusulaiNative = N;

  // 1) Site kendini ana ekran (standalone) uygulaması olarak görsün
  try { Object.defineProperty(navigator, "standalone", { get: function () { return true; }, configurable: true }); } catch (e) {}
  if (window.matchMedia) {
    var origMM = window.matchMedia.bind(window);
    window.matchMedia = function (q) {
      if (typeof q === "string") {
        if (/display-mode\s*:\s*(standalone|fullscreen)/i.test(q)) return origMM("all");
        if (/display-mode\s*:\s*(browser|minimal-ui)/i.test(q)) return origMM("not all");
      }
      return origMM(q);
    };
  }

  // 2) Web Notification -> iPhone yerel bildirimi
  function NativeNotification(title, options) {
    options = options || {};
    this.title = String(title || "");
    this.body = options.body ? String(options.body) : "";
    this.tag = options.tag ? String(options.tag) : "";
    this.data = options.data;
    this.icon = options.icon;
    this.onclick = null; this.onclose = null; this.onshow = null; this.onerror = null;
    if (state.permission === "granted") {
      var url = (options.data && options.data.url) || (location.pathname + location.search + location.hash);
      post({ type: "notify", title: this.title, body: this.body, tag: this.tag, url: String(url) });
      var self = this;
      setTimeout(function () { if (typeof self.onshow === "function") try { self.onshow(); } catch (e) {} }, 0);
    }
  }
  NativeNotification.prototype.close = function () {
    if (this.tag) post({ type: "closeNotification", tag: this.tag });
  };
  NativeNotification.prototype.addEventListener = function () {};
  NativeNotification.prototype.removeEventListener = function () {};
  NativeNotification.prototype.dispatchEvent = function () { return true; };
  Object.defineProperty(NativeNotification, "permission", { get: function () { return state.permission; } });
  NativeNotification.maxActions = 0;
  NativeNotification.requestPermission = function (cb) {
    return new Promise(function (resolve) {
      if (state.permission !== "default") {
        if (typeof cb === "function") cb(state.permission);
        resolve(state.permission);
        return;
      }
      var id = ++state.reqId;
      state.pending[id] = function (p) { if (typeof cb === "function") cb(p); resolve(p); };
      post({ type: "requestPermission", id: id });
    });
  };
  try {
    Object.defineProperty(window, "Notification", { value: NativeNotification, writable: true, configurable: true });
  } catch (e) {
    try { window.Notification = NativeNotification; } catch (e2) {}
  }

  // 3) navigator.vibrate -> iPhone titreşimi (haptic)
  try {
    Object.defineProperty(navigator, "vibrate", {
      value: function () { post({ type: "haptic" }); return true; },
      writable: true, configurable: true
    });
  } catch (e) {}

  // 4) Tema rengi (aydınlık mavi / karanlık) -> durum çubuğu rengi
  var lastSent = "";
  function sendTheme() {
    var m = document.querySelector('meta[name="theme-color"]');
    var dark = document.documentElement.classList.contains("dark");
    var color = m ? m.getAttribute("content") : "";
    var key = color + "|" + dark;
    if (key === lastSent) return;
    lastSent = key;
    post({ type: "theme", color: color || "", dark: dark });
  }
  function watchTheme() {
    sendTheme();
    try {
      new MutationObserver(sendTheme).observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
      if (document.head) new MutationObserver(sendTheme).observe(document.head, { subtree: true, childList: true, attributes: true, attributeFilter: ["content"] });
    } catch (e) {}
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", watchTheme);
  else watchTheme();

  // 5) Favori maçlar -> Dinamik Ada / kilit ekranı + sunucu bildirim kaydı
  //    Sitenin zaten yaptığı /api/live-fixtures ve /api/live-scores yanıtları okunur (ek yük yok).
  var fx = {};
  var haveFixtures = false;
  var lastFixturesAt = 0;
  var lastLive = "";
  var lastFavs = "";

  function normTeam(s) {
    return String(s || "").toLocaleLowerCase("tr-TR").normalize("NFD")
      .replace(/[̀-ͯ]/g, "").replace(/ı/g, "i").replace(/[^a-z0-9]/g, "");
  }
  function parseScore(s) {
    var m = String(s || "").match(/(\d+)\s*[-:]\s*(\d+)/);
    return m ? [parseInt(m[1], 10), parseInt(m[2], 10)] : null;
  }
  function fmtMinute(raw) {
    var t = String(raw || "").replace(/[‎‏‪-‮⁦-⁩]/g, "").replace(/['"’′″`´]/g, "").trim();
    if (!t) return "Canlı";
    if (/^(ht|iy|İy|İY|devre|half)/i.test(t)) return "İY";
    var p = t.match(/^(\d{1,3})\s*\+\s*(\d{1,2})/);
    if (p) return p[1] + "+" + p[2] + "'";
    var n = t.match(/^(\d{1,3})\b/);
    if (n) return n[1] + "'";
    return t;
  }
  function hhmm(ts) {
    var d = new Date(ts);
    return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
  }

  function ingestFixtures(list) {
    if (!Array.isArray(list)) return;
    var next = {};
    list.forEach(function (m) {
      if (!m || !m.home || !m.away) return;
      var k = normTeam(m.home) + "|" + normTeam(m.away);
      var old = fx[k];
      var o = parseScore(old && old.finalScore), n = parseScore(m.finalScore);
      // Ağır bülten canlı skordan geride kalabilir: skoru geri alma
      if (old && o && n && m.matchState === "live" && o[0] + o[1] > n[0] + n[1]) {
        m = Object.assign({}, m, { finalScore: old.finalScore, liveMinute: old.liveMinute });
      }
      next[k] = m;
    });
    fx = next;
    haveFixtures = true;
    lastFixturesAt = Date.now();
  }

  function ingestScores(d) {
    var byId = {}, byFm = {};
    (Array.isArray(d.scores) ? d.scores : []).forEach(function (s) { byId[String(s.eventId)] = s; });
    (Array.isArray(d.fotmob) ? d.fotmob : []).forEach(function (f) { byFm[String(f.matchId)] = f; });
    Object.keys(fx).forEach(function (k) {
      var m = fx[k];
      var sc = m.espnEventId ? byId[String(m.espnEventId)] : null;
      if (!sc && !m.espnEventId && m.fotmobMatchId) {
        var f = byFm[String(m.fotmobMatchId)];
        if (f) sc = { homeScore: f.homeScore, awayScore: f.awayScore, state: f.state, clock: f.minute, isHalftime: f.isHalftime };
      }
      if (!sc) return;
      var old = parseScore(m.finalScore);
      if (old && m.matchState === "live" && old[0] + old[1] > sc.homeScore + sc.awayScore) return;
      var st = sc.state === "post" ? "played" : "live";
      fx[k] = Object.assign({}, m, {
        finalScore: sc.homeScore + " - " + sc.awayScore,
        matchState: st,
        liveMinute: st === "live" ? (sc.isHalftime ? "İY" : (sc.clock || m.liveMinute)) : m.liveMinute
      });
    });
  }

  var origFetch = window.fetch ? window.fetch.bind(window) : null;
  if (origFetch) {
    window.fetch = function (input, init) {
      var p = origFetch(input, init);
      try {
        var url = typeof input === "string" ? input : (input && input.url) || "";
        var isFx = url.indexOf("/api/live-fixtures") >= 0;
        var isSc = url.indexOf("/api/live-scores") >= 0;
        if (isFx || isSc) {
          var dm = url.match(/[?&]day=([^&#]*)/);
          if (!(isFx && dm && decodeURIComponent(dm[1]) !== "today")) {
            p.then(function (res) {
              if (!res || !res.ok) return;
              res.clone().json().then(function (d) {
                if (isFx) ingestFixtures(d && d.matches); else ingestScores(d || {});
                scheduleSync();
              }).catch(function () {});
            }).catch(function () {});
          }
        }
      } catch (e) {}
      return p;
    };
  }

  function readFavorites() {
    try {
      var l = JSON.parse(localStorage.getItem("pusulai_favorites") || "[]");
      return Array.isArray(l) ? l : [];
    } catch (e) { return []; }
  }
  function findMatch(key) {
    if (fx[key]) return fx[key];
    var parts = key.split("|"), h = parts[0], a = parts[1];
    if (!h || !a) return null;
    var ks = Object.keys(fx);
    for (var i = 0; i < ks.length; i++) {
      var p = ks[i].split("|");
      if (p[0].indexOf(h) >= 0 && p[1].indexOf(a) >= 0) return fx[ks[i]];
    }
    return null;
  }

  function sync() {
    var favs = readFavorites();

    // Sunucuya kayıt için favori anahtarları (+ gol alarmı kapalı işareti, site ile aynı)
    var keys = favs.filter(function (f) { return f && f.key; }).map(function (f) { return String(f.key); });
    try { if (localStorage.getItem("pusulai_goal_alert_notify") === "0") keys.push("__goal_alerts_off__"); } catch (e) {}
    var fk = JSON.stringify(keys);
    if (fk !== lastFavs) { lastFavs = fk; post({ type: "favorites", keys: keys }); }

    if (!haveFixtures) return;
    var now = Date.now(), out = [];
    favs.forEach(function (f) {
      if (!f || !f.key) return;
      var m = findMatch(f.key);
      var ko = (m && m.kickoffTs) || f.kickoffTs || 0;
      var sc = m ? parseScore(m.finalScore) : null;
      var state = m ? m.matchState : "upcoming";
      var item = {
        key: String(f.key),
        home: String((m && (m.homeFullName || m.home)) || f.home || ""),
        away: String((m && (m.awayFullName || m.away)) || f.away || ""),
        league: String((m && m.league) || f.league || ""),
        hs: sc ? sc[0] : 0,
        as: sc ? sc[1] : 0,
        homeLogo: String((m && m.homeLogo) || ""),
        awayLogo: String((m && m.awayLogo) || ""),
        espnEventId: String((m && m.espnEventId) || ""),
        espnLeague: String((m && m.espnLeague) || ""),
        fotmobId: Number((m && m.fotmobMatchId) || 0)
      };
      if (state === "live") {
        item.minute = fmtMinute(m.liveMinute);
        item.phase = item.minute === "İY" ? "ht" : "live";
      } else if (state === "played" || state === "finished") {
        if (!ko || now - ko > 4 * 3600e3) return;
        item.phase = "ended"; item.minute = "MS";
      } else {
        if (!ko || ko - now > 3 * 3600e3 || now - ko > 3 * 3600e3) return;
        item.phase = "pre"; item.minute = hhmm(ko);
      }
      out.push(item);
    });
    var s = JSON.stringify(out);
    if (s === lastLive) return;
    lastLive = s;
    post({ type: "live", matches: out });
  }

  // 6) Site sesleri -> uygulamanın kendi ses çalıcısı
  //    (sayfa içinde çalınca iPhone bunu müzik sanıp kilit ekranında oynatıcı açıyordu)
  var SOUND_RE = /\/sounds\/([a-z0-9_-]+)\.mp3/i;
  function soundName(u) { var x = String(u || "").match(SOUND_RE); return x ? x[1].toLowerCase() : null; }
  var bufTag = new WeakMap(), audioTag = new WeakMap();
  try {
    var origAB = Response.prototype.arrayBuffer;
    Response.prototype.arrayBuffer = function () {
      var name = soundName(this.url);
      var pr = origAB.apply(this, arguments);
      if (!name) return pr;
      return pr.then(function (ab) { try { bufTag.set(ab, name); } catch (e) {} return ab; });
    };
  } catch (e) {}
  try {
    var ACtor = window.AudioContext || window.webkitAudioContext;
    var acProto = window.BaseAudioContext ? window.BaseAudioContext.prototype : (ACtor && ACtor.prototype);
    if (acProto && acProto.decodeAudioData) {
      var origDecode = acProto.decodeAudioData;
      acProto.decodeAudioData = function (data, ok, fail) {
        var name = null;
        try { name = data ? bufTag.get(data) : null; } catch (e) {}
        if (!name) return origDecode.apply(this, arguments);
        var tagIt = function (buf) { try { audioTag.set(buf, name); } catch (e) {} return buf; };
        var r = origDecode.call(this, data, function (buf) { tagIt(buf); if (ok) ok(buf); }, fail);
        return (r && r.then) ? r.then(tagIt) : r;
      };
    }
    if (window.AudioBufferSourceNode) {
      var origStart = AudioBufferSourceNode.prototype.start;
      AudioBufferSourceNode.prototype.start = function () {
        var name = null;
        try { name = this.buffer ? audioTag.get(this.buffer) : null; } catch (e) {}
        if (name) { post({ type: "sound", name: name }); return; }
        return origStart.apply(this, arguments);
      };
    }
  } catch (e) {}
  try {
    var origPlay = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () {
      var name = soundName(this.currentSrc || this.src);
      if (name) { post({ type: "sound", name: name }); return Promise.resolve(); }
      return origPlay.apply(this, arguments);
    };
  } catch (e) {}

  var syncTimer = null;
  function scheduleSync() {
    if (syncTimer) return;
    syncTimer = setTimeout(function () { syncTimer = null; sync(); }, 300);
  }
  N.syncLive = function () { lastLive = ""; lastFavs = ""; sync(); };

  setInterval(function () {
    sync();
    // Uygulama arka plandayken site ağır bülteni yenilemez; favori varsa dakikada bir kendimiz çekeriz
    if (origFetch && Date.now() - lastFixturesAt > 60000 && readFavorites().length) {
      lastFixturesAt = Date.now();
      origFetch("/api/live-fixtures?day=today", { cache: "no-store" })
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (d) { if (d) { ingestFixtures(d.matches); sync(); } })
        .catch(function () {});
    }
  }, 5000);
})();
"""#
}
