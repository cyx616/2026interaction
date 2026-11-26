import processing.sound.*;
import processing.serial.*;
import java.util.ArrayList;

// ============================================
// 音速節拍 - 8-BIT RHYTHM GAME
// 修正版：黑畫面排除、中文介面、手動計分
// ============================================

// 基準設計尺寸
final int DESIGN_W = 960;
final int DESIGN_H = 700;

// Arduino
String preferredPort = "COM3";
Serial port;
boolean arduinoReady = false;

// 音樂模式
String[] patchNames = {
  "25% 脈衝波",
  "柔和三角波",
  "街機鋸齒波"
};

String[] patchFiles = {
  "lead_pulse.wav",
  "lead_triangle.wav",
  "lead_saw.wav"
};

char[] laneKeys = {'a', 's', 'd', 'f'};

color[] neon = {
  #00E9F4,
  #F872FA,
  #FFE16E,
  #81F797
};

// 背景音樂
SoundFile[] leads = new SoundFile[3];
SoundFile bass, arp, drums;

float[] leadMix = {0, 0, 0};
float bassMix = 0;
float arpMix = 0;
float drumMix = 0;

// 電子按鍵音效
Pulse[] pulseVoices = new Pulse[4];
TriOsc[] triangleVoices = new TriOsc[4];
SawOsc[] sawVoices = new SawOsc[4];

int[] hitAt = {-9999, -9999, -9999, -9999};
int[] hitFlash = {-9999, -9999, -9999, -9999};

int patchMode = 0;
int musicVolume = 60;

boolean accompanimentEnabled = true;
boolean tracksStarted = false;
boolean assetsLoaded = false;
boolean voicesReady = false;

// ============================================
// 啟動階段
// ============================================

// 0：顯示載入畫面
// 1：載入音樂與譜面
// 2：初始化電子音效
// 3：連接 Arduino
// 4：進入正式畫面
int initPhase = 0;

String initStatus = "正在啟動音速節拍...";
boolean audioUpdateErrorShown = false;

// 遊戲狀態
// 0：錯誤
// 1：選單
// 2：遊玩
// 3：暫停
// 4：結算

int state = 1;
String errorMessage = "";

String songTitle = "8-BIT POP";
String sourceMidi = "";

float bpm = 125.0f;
int durationMs = 32000;

// 譜面
ArrayList<RhythmNote> sourceNotes =
  new ArrayList<RhythmNote>();

ArrayList<RhythmNote> notes =
  new ArrayList<RhythmNote>();

String[] difficultyNames = {
  "EASY", "NORMAL", "HARD"
};

int[] noteGapsMs = {
  720, 480, 240
};

int difficulty = 0;

// 計分
int score = 0;
int combo = 0;
int maxCombo = 0;

int perfectCount = 0;
int goodCount = 0;
int missCount = 0;

int gameStart;
int pauseStart;
int pausedTotal;

// 音符下落
int preRollMs = 2600;
int travelTimeMs = 2400;

final int PERFECT_WINDOW_MS = 150;
final int GOOD_WINDOW_MS = 350;
final int HIT_WINDOW_MS = GOOD_WINDOW_MS;

// 軌道位置
final int TRACK_X = 150;
final int TRACK_W = 157;
final int TRACK_TOP = 194;
final int TRACK_BOTTOM = 615;

// 打擊效果
int judgeLane = -1;
int lastGain = 0;

int[] tapFlash = {-9999, -9999, -9999, -9999};
int[] laneJudgeTime = {-9999, -9999, -9999, -9999};

String[] laneJudge = {"", "", "", ""};

int emptyTapCount = 0;
int[] bestScores = {0, 0, 0};

int lastLedSend = 0;

String judgeText = "";
int judgeAt = -9999;

// 字型
PFont arcadeFont;
PFont zhFont;


// ============================================
// 1. Processing 初始化
// ============================================

void settings() {

  // 改用預設 Java2D
  // 不再使用 P2D
  size(DESIGN_W, DESIGN_H);

  noSmooth();
}


void setup() {

  surface.setResizable(true);

  frameRate(60);
  rectMode(CORNER);
  textAlign(CENTER, CENTER);

  try {

    arcadeFont =
      createFont("Consolas", 28, true);

    zhFont =
      createFont("Microsoft JhengHei", 22, true);

  } catch (Exception e) {

    println("字型初始化失敗：" + e.getMessage());

    arcadeFont =
      createFont("Monospaced", 28, true);

    zhFont =
      createFont("SansSerif", 22, true);
  }

  // 音效及 Arduino 移到載入階段
  // 不在 setup() 一開始全部執行

  println("SETUP COMPLETE");
  println("準備開始載入遊戲資源...");
}


// ============================================
// 2. 初始化電子音效
// ============================================

void initVoices() {

  for (int i = 0; i < 4; i++) {

    pulseVoices[i] = new Pulse(this);
    pulseVoices[i].play(440, 0);
    pulseVoices[i].width(0.25f);

    triangleVoices[i] = new TriOsc(this);
    triangleVoices[i].play(440, 0);

    sawVoices[i] = new SawOsc(this);
    sawVoices[i].play(440, 0);
  }
}


// ============================================
// 3. 載入音樂與譜面
// ============================================

boolean loadAssets() {

  try {

    JSONObject map = loadJSONObject("beatmap.json");

    if (map == null) {
      throw new RuntimeException(
        "找不到 beatmap.json"
      );
    }

    songTitle = map.getString("title");
    sourceMidi = map.getString("source");
    bpm = map.getFloat("bpm");
    durationMs = map.getInt("durationMs");

    JSONArray items = map.getJSONArray("notes");

    sourceNotes.clear();

    for (int i = 0; i < items.size(); i++) {

      JSONObject n = items.getJSONObject(i);

      sourceNotes.add(
        new RhythmNote(
          constrain(n.getInt("lane"), 0, 3),
          n.getInt("startMs"),
          n.getInt("pitch")
        )
      );
    }

    if (sourceNotes.size() == 0) {
      throw new RuntimeException(
        "譜面內沒有可用音符"
      );
    }

    java.util.Collections.sort(
      sourceNotes,
      new java.util.Comparator<RhythmNote>() {

        public int compare(
          RhythmNote a,
          RhythmNote b
        ) {
          return Integer.compare(
            a.hitTime,
            b.hitTime
          );
        }
      }
    );

    buildChart();

    for (int i = 0; i < 3; i++) {

      leads[i] =
        new SoundFile(this, patchFiles[i]);
    }

    bass = new SoundFile(this, "bass.wav");
    arp = new SoundFile(this, "arp.wav");
    drums = new SoundFile(this, "drums.wav");

    println("音樂載入成功！");
    println("音符數量：" + notes.size());

    return true;

  } catch (Exception e) {

    errorMessage = e.getMessage();

    println("Loading error: " + errorMessage);
    e.printStackTrace();

    return false;
  }
}


// ============================================
// 4. 譜面難度
// ============================================

void buildChart() {

  notes.clear();

  int lastHit = -1000000;
  int minGap = noteGapsMs[difficulty];

  for (RhythmNote src : sourceNotes) {

    if (src.hitTime - lastHit >= minGap) {

      notes.add(
        new RhythmNote(
          src.lane,
          src.hitTime,
          src.pitch
        )
      );

      lastHit = src.hitTime;
    }
  }

  println(
    "Difficulty " + difficultyNames[difficulty] +
    ": " + notes.size() + " notes"
  );
}


void cycleDifficulty() {

  difficulty = (difficulty + 1) % 3;

  buildChart();

  if (state == 2 || state == 3) {
    startGame();
  } else if (state == 4) {
    state = 1;
  }
}


// ============================================
// 5. Arduino 連線
// ============================================

void connectArduino() {

  String[] ports = Serial.list();

  printArray(ports);

  String chosen = "";

  for (int i = 0; i < ports.length; i++) {

    if (ports[i].equalsIgnoreCase(preferredPort)) {
      chosen = ports[i];
      break;
    }
  }

  if (chosen.equals("") && ports.length > 0) {
    chosen = ports[0];
  }

  if (!chosen.equals("")) {

    try {

      port = new Serial(this, chosen, 9600);
      port.bufferUntil('\n');

      arduinoReady = true;

      println("Arduino connected: " + chosen);

      sendArduino('X');

    } catch (Exception e) {

      arduinoReady = false;

      println(
        "Arduino 無法連線，可以使用鍵盤：" +
        e.getMessage()
      );
    }
  }
}


// ============================================
// 6. 主畫面繪製
// ============================================

void draw() {

  drawBackground();

  // 自動計算視窗縮放比例

  float fitScale = min(
    width / (float)DESIGN_W,
    height / (float)DESIGN_H
  );

  float offsetX =
    (width - DESIGN_W * fitScale) * 0.5f;

  float offsetY =
    (height - DESIGN_H * fitScale) * 0.5f;

  pushMatrix();

  translate(offsetX, offsetY);
  scale(fitScale);

  try {

    if (initPhase < 4) {

      drawLoading();

    } else if (state == 0) {

      drawError();

    } else if (state == 1) {

      drawMenu();

    } else if (state == 2 || state == 3) {

      if (state == 2) {
        updateGame();
      }

      if (state == 4) {

        drawResult();

      } else {

        drawGame();

        if (state == 3) {
          drawPause();
        }
      }

    } else if (state == 4) {

      drawResult();
    }

  } catch (Exception e) {

    state = 0;

    errorMessage =
      "畫面執行錯誤：" +
      e.getClass().getSimpleName() +
      " " + e.getMessage();

    println(errorMessage);
    e.printStackTrace();

    // 即使介面錯誤，也嘗試顯示提示

    noStroke();
    fill(#FF7B9E);

    textFont(zhFont);
    textSize(18);

    text(
      "畫面錯誤，請查看 Processing 主控台",
      DESIGN_W/2, 350
    );

  } finally {

    popMatrix();
  }

  // 先完成畫面，再執行初始化

  if (initPhase < 4) {

    advanceInitialization();

    return;
  }

  // 音效更新放在畫面繪製之後

  if (assetsLoaded) {

    try {

      if (voicesReady) {
        updateHitSound();
      }

      updateVolumes();

    } catch (Exception e) {

      if (!audioUpdateErrorShown) {

        audioUpdateErrorShown = true;

        println(
          "音效更新失敗：" + e.getMessage()
        );

        e.printStackTrace();
      }
    }
  }
}


// ============================================
// 7. 遊戲載入畫面
// ============================================

void drawLoading() {

  titleBar();

  textFont(zhFont);

  fill(#FFFFFF);
  textSize(25);

  text(
    "正在載入遊戲...",
    DESIGN_W/2, 300
  );

  fill(#FFE16E);
  textSize(17);

  text(
    initStatus,
    DESIGN_W/2, 350
  );

  fill(#8EB6D7);
  textSize(14);

  text(
    "如果停留在此畫面，請查看 Processing 下方錯誤訊息",
    DESIGN_W/2, 400
  );
}


// ============================================
// 8. 分階段載入
// ============================================

void advanceInitialization() {

  if (initPhase == 0) {

    initStatus =
      "讀取 beatmap.json 與 6 個 WAV 音檔";

    initPhase = 1;
    return;
  }

  if (initPhase == 1) {

    assetsLoaded = loadAssets();

    state = assetsLoaded ? 1 : 0;

    initStatus = assetsLoaded ?
      "音樂載入成功，初始化按鍵音效" :
      "音檔載入失敗";

    initPhase = 2;
    return;
  }

  if (initPhase == 2) {

    if (assetsLoaded) {

      try {

        initVoices();
        voicesReady = true;

      } catch (Exception e) {

        voicesReady = false;

        println(
          "電子音效初始化失敗：" +
          e.getMessage()
        );

        e.printStackTrace();
      }
    }

    initStatus =
      "連接 Arduino（未連接也能用鍵盤）";

    initPhase = 3;
    return;
  }

  if (initPhase == 3) {

    try {

      connectArduino();

    } catch (Exception e) {

      arduinoReady = false;

      println(
        "Arduino 連線略過：" +
        e.getMessage()
      );
    }

    initPhase = 4;
  }
}


// ============================================
// 9. 背景
// ============================================

void drawBackground() {

  background(#090D1C);

  stroke(255, 255, 255, 11);

  for (int x = 0; x < width; x += 40) {
    line(x, 0, x, height);
  }

  for (int y = 0; y < height; y += 40) {
    line(0, y, width, y);
  }

  noStroke();

  for (int y = 0; y < height; y += 5) {

    fill(0, 0, 0, 24);
    rect(0, y, width, 2);
  }
}


// ============================================
// 10. 中文標題
// ============================================

void titleBar() {

  textAlign(CENTER, CENTER);

  textFont(zhFont);
  fill(#00E9F4);
  textSize(42);

  text(
    "音速節拍",
    DESIGN_W/2, 48
  );

  textFont(arcadeFont);
  fill(#FFE16E);
  textSize(14);

  text(
    "PIXEL BEATS - 8-BIT RHYTHM GAME",
    DESIGN_W/2, 80
  );
}


// ============================================
// 11. 開始選單
// ============================================

void drawMenu() {

  titleBar();

  fill(#131B35);
  stroke(#F872FA);
  strokeWeight(3);

  rect(124, 126, 712, 472, 8);

  noStroke();

  textFont(arcadeFont);
  fill(#FFFFFF);
  textSize(29);

  text(
    songTitle,
    DESIGN_W/2, 168
  );

  fill(#A6B8DF);
  textSize(15);

  text(
    "MIDI: " + sourceMidi,
    DESIGN_W/2, 203
  );

  fill(#162542);
  stroke(#FFE16E);
  strokeWeight(1);

  rect(310, 215, 340, 32, 5);

  noStroke();
  fill(#FFE16E);
  textSize(14);

  text(
    "LEVEL: " + difficultyNames[difficulty] +
    "   " + notes.size() +
    " NOTES   [Q / CLICK]",
    DESIGN_W/2, 230
  );

  fill(#81F797);
  textFont(zhFont);
  textSize(22);

  text(
    "手動節奏挑戰",
    DESIGN_W/2, 289
  );

  textFont(arcadeFont);

  fill(#00E9F4);
  rect(310, 345, 340, 64, 6);

  fill(#091021);
  textSize(26);

  text(
    "START  [ENTER]",
    DESIGN_W/2, 377
  );

  fill(#F872FA);
  textSize(17);

  text(
    "A / S / D / F  OR  MOUSE CLICK",
    DESIGN_W/2, 449
  );

  fill(#BEC9E7);
  textSize(15);

  text(
    "HIT WHEN NOTES REACH THE WHITE LINE",
    DESIGN_W/2, 482
  );

  textFont(zhFont);
  textSize(15);

  text(
    "空白鍵：暫停  ｜  Q：切換難度",
    DESIGN_W/2, 515
  );

  text(
    "1/2/3：音色  Q：難度  B：伴奏  上／下：音量",
    DESIGN_W/2, 544
  );

  textFont(arcadeFont);
  fill(#81F797);
  textSize(17);

  text(
    "BEST SCORE: " + bestScores[difficulty],
    DESIGN_W/2, 582
  );

  textFont(zhFont);
  fill(#FFE16E);
  textSize(16);

  text(
    "手動挑戰：跟隨節奏敲擊音符，挑戰最高分數！",
    DESIGN_W/2, 643
  );
}


// ============================================
// 12. 錯誤畫面
// ============================================

void drawError() {

  titleBar();

  textFont(zhFont);
  fill(#FF7B9E);
  textSize(24);

  text(
    "讀取音檔或譜面失敗",
    DESIGN_W/2, 290
  );

  textSize(16);

  text(
    errorMessage,
    DESIGN_W/2, 341
  );

  text(
    "請檢查 data 資料夾內的 6 個 WAV 與 beatmap.json",
    DESIGN_W/2, 391
  );
}


// ============================================
// 13. 開始遊戲
// ============================================

void startGame() {

  if (!assetsLoaded) return;

  stopTracks();

  score = 0;
  combo = 0;
  maxCombo = 0;

  perfectCount = 0;
  goodCount = 0;
  missCount = 0;

  judgeText = "";
  judgeAt = -9999;
  judgeLane = -1;
  lastGain = 0;

  emptyTapCount = 0;

  for (int i = 0; i < 4; i++) {

    hitFlash[i] = -9999;
    hitAt[i] = -9999;
    tapFlash[i] = -9999;
    laneJudgeTime[i] = -9999;
    laneJudge[i] = "";
  }

  for (RhythmNote n : notes) {
    n.done = false;
  }

  pausedTotal = 0;

  gameStart = millis();
  tracksStarted = false;

  state = 2;

  println("Game start: manual");
}


// ============================================
// 14. 歌曲時間
// ============================================

int songTime() {

  int current =
    state == 3 ? pauseStart : millis();

  return current -
    gameStart -
    pausedTotal -
    preRollMs;
}


// ============================================
// 15. 播放音樂
// ============================================

void playTracks() {

  for (int i = 0; i < 3; i++) {

    leads[i].cue(0);
    leads[i].amp(0);
    leads[i].play();

    leadMix[i] = 0;
  }

  bass.cue(0);
  bass.amp(0);
  bass.play();

  arp.cue(0);
  arp.amp(0);
  arp.play();

  drums.cue(0);
  drums.amp(0);
  drums.play();

  bassMix = 0;
  arpMix = 0;
  drumMix = 0;

  tracksStarted = true;
}


void applyVolumes() {

  // 實際音量調整由 updateVolumes() 處理
}


void updateVolumes() {

  if (!assetsLoaded) return;

  float volume = musicVolume / 100.0f;

  for (int i = 0; i < 3; i++) {

    float target =
      (i == patchMode) ?
      volume * 0.55f : 0;

    leadMix[i] +=
      (target - leadMix[i]) * 0.15f;

    leads[i].amp(leadMix[i]);
  }

  float bassTarget =
    accompanimentEnabled ?
    volume * 0.82f : 0;

  float arpTarget =
    accompanimentEnabled ?
    volume * 0.70f : 0;

  bassMix +=
    (bassTarget - bassMix) * 0.15f;

  arpMix +=
    (arpTarget - arpMix) * 0.15f;

  
  float drumTarget =
    accompanimentEnabled ? volume * 0.85f : 0;
  
  drumMix +=
    (drumTarget - drumMix) * 0.15f;


  bass.amp(bassMix);
  arp.amp(arpMix);
  drums.amp(drumMix);
}


void pauseTracks() {

  if (!tracksStarted) return;

  for (SoundFile lead : leads) {
    lead.pause();
  }

  bass.pause();
  arp.pause();
  drums.pause();
}


void resumeTracks() {

  if (!tracksStarted) return;

  for (SoundFile lead : leads) {
    lead.play();
  }

  bass.play();
  arp.play();
  drums.play();

  applyVolumes();
}


void stopTracks() {

  if (!assetsLoaded) return;

  for (SoundFile lead : leads) {

    if (lead != null) {
      lead.stop();
    }
  }

  if (bass != null) bass.stop();
  if (arp != null) arp.stop();
  if (drums != null) drums.stop();

  tracksStarted = false;
}


// ============================================
// 16. 遊戲判定更新
// ============================================

void updateGame() {

  int t = songTime();

  if (!tracksStarted && t >= 0) {
    playTracks();
  }

  // 只保留手動演奏

  for (RhythmNote n : notes) {

    if (!n.done &&
        t > n.hitTime + HIT_WINDOW_MS) {

      n.done = true;

      missCount++;
      combo = 0;

      laneJudge[n.lane] = "MISS";
      laneJudgeTime[n.lane] = millis();

      judgeLane = n.lane;
      lastGain = 0;

      showJudge("MISS");
    }
  }

  sendBeatLed(t);

  if (t > durationMs) {
    finishGame();
  }
}


// ============================================
// 17. Arduino 節奏燈
// ============================================

void sendBeatLed(int t) {

  if (!arduinoReady ||
      port == null ||
      t < 0 ||
      bpm <= 0 ||
      millis() - lastLedSend < 70) {
    return;
  }

  lastLedSend = millis();

  float beatLength = 60000.0f / bpm;

  float phase =
    (t % ((int)beatLength)) / beatLength;

  int light = constrain(
    (int)(9 * exp(-phase * 6)),
    0, 9
  );

  port.write("L" + light + "\n");
}


// ============================================
// 18. 遊戲畫面
// ============================================

void drawGame() {

  titleBar();

  textFont(arcadeFont);

  fill(#FFFFFF);
  textSize(20);

  text("SCORE " + score, 215, 112);
  text("COMBO " + combo, 739, 112);

  fill(#8EB6D7);
  textFont(zhFont);
  textSize(15);

  text(
    "音色：" + patchNames[patchMode] +
    "  ｜  音量：" + musicVolume + "%" +
    "  ｜  電子伴奏：" +
    (accompanimentEnabled ? "開啟" : "關閉"),
    DESIGN_W/2, 145
  );

  textFont(arcadeFont);

  int t = songTime();

  float p = constrain(
    t / (float)durationMs,
    0, 1
  );

  fill(#1A2848);
  rect(TRACK_X, 164, 628, 10);

  fill(#00E9F4);
  rect(TRACK_X, 164, 628 * p, 10);

  noStroke();

  // 四條軌道
  for (int i = 0; i < 4; i++) {

    int x = TRACK_X + i * TRACK_W;

    fill(#121A30);
    stroke(neon[i], 105);
    strokeWeight(2);

    rect(
      x + 3,
      TRACK_TOP,
      TRACK_W - 6,
      365
    );

    noStroke();

    if (millis() - hitFlash[i] < 160) {

      fill(neon[i], 85);

      rect(
        x + 7,
        TRACK_TOP + 4,
        TRACK_W - 14,
        354
      );
    }

    if (millis() - tapFlash[i] < 300) {

      fill(#FFFFFF, 40);

      rect(
        x + 3,
        485,
        TRACK_W - 6,
        75
      );
    }

    fill(
      millis() - tapFlash[i] < 300 ?
      neon[i] : #253450
    );

    stroke(neon[i]);
    strokeWeight(2);

    rect(
      x + 20,
      572,
      TRACK_W - 40,
      40, 4
    );

    noStroke();

    fill(
      millis() - tapFlash[i] < 300 ?
      #091021 : neon[i]
    );

    textFont(arcadeFont);
    textSize(24);

    text(
      Character.toString(
        laneKeys[i]
      ).toUpperCase(),
      x + TRACK_W/2,
      592
    );

    if (millis() - laneJudgeTime[i] < 420) {

      float age =
        (millis() - laneJudgeTime[i]) / 420.0f;

      fill(
        laneJudge[i].equals("PERFECT") ?
        #81F797 :
        laneJudge[i].equals("GOOD") ?
        #FFE16E : #FF7B9E
      );

      textSize(13);

      text(
        laneJudge[i],
        x + TRACK_W/2,
        462 - 18 * age
      );
    }
  }

  // 白色判定線
  stroke(#FFFFFF);
  strokeWeight(3);

  line(TRACK_X, 522, 778, 522);

  noStroke();

  // 畫出音符
  for (RhythmNote n : notes) {

    if (n.done) continue;

    float remain = n.hitTime - t;

    float y =
      522 - remain * (522 - 205) / travelTimeMs;

    if (y >= TRACK_TOP && y <= 552) {

      int x =
        TRACK_X + n.lane * TRACK_W;

      fill(neon[n.lane], 45);

      rect(
        x + 15,
        y - 16,
        TRACK_W - 30,
        34, 3
      );

      fill(neon[n.lane]);

      rect(
        x + 23,
        y - 10,
        TRACK_W - 46,
        22, 2
      );

      fill(#0C1223);
      textSize(11);

      text(
        midiName(n.pitch),
        x + TRACK_W/2,
        y + 1
      );
    }
  }

  // 暫停按鈕
  fill(#1B2741);
  stroke(#8AA1C8);
  strokeWeight(2);

  rect(797, 204, 130, 49, 5);

  noStroke();
  fill(#FFFFFF);

  textSize(16);
  text("II PAUSE", 862, 228);

  // 手動模式資訊
  fill(#1B2741);
  stroke(#81F797);
  strokeWeight(2);

  rect(797, 273, 130, 90, 5);

  noStroke();
  fill(#81F797);

  textFont(zhFont);
  textSize(18);

  text("手動挑戰", 862, 295);

  fill(#9CACC9);
  textSize(14);

  text("節奏計分模式", 862, 330);

  // 統計資料
  textFont(arcadeFont);

  fill(#FFFFFF);
  textSize(13);

  text("PERFECT " + perfectCount, 862, 405);
  text("GOOD " + goodCount, 862, 429);
  text("MISS " + missCount, 862, 453);

  fill(#81F797);
  text(
    "BEST " + bestScores[difficulty],
    862, 488
  );

  // 難度按鈕
  fill(#1B2741);
  stroke(#FFE16E);
  strokeWeight(1.5f);

  rect(797, 510, 130, 69, 5);

  noStroke();
  fill(#FFE16E);
  textSize(15);

  text(
    "LEVEL " + difficultyNames[difficulty],
    862, 532
  );

  fill(#A6B8DF);
  textSize(12);

  text(notes.size() + " NOTES", 862, 554);
  text("Q / CLICK", 862, 572);

  // 預備倒數
  if (t < 0) {

    fill(#FFFFFF);
    textSize(35);

    text(
      "READY " +
      max(1, (int)ceil(-t / 1000.0f)),
      DESIGN_W/2, 388
    );
  }

  // 判定顯示
  if (millis() - judgeAt < 475) {

    fill(
      judgeText.equals("PERFECT") ? #81F797 :
      judgeText.equals("GOOD") ? #FFE16E :
      (judgeText.equals("EMPTY") ||
       judgeText.equals("READY")) ?
      #9AAEDF : #FF7B9E
    );

    textSize(30);

    text(
      judgeText +
      (lastGain > 0 ? "  +" + lastGain : ""),
      DESIGN_W/2, 650
    );

  } else {

    fill(#8797BE);
    textSize(15);

    text(
      "HIT A / S / D / F OR CLICK EACH LANE",
      DESIGN_W/2, 650
    );
  }
}


// ============================================
// 19. MIDI 音名
// ============================================

String midiName(int pitch) {

  String[] names = {
    "C", "C#", "D", "D#",
    "E", "F", "F#", "G",
    "G#", "A", "A#", "B"
  };

  return names[pitch % 12] +
    Integer.toString(pitch / 12 - 1);
}


// ============================================
// 20. 按鍵電子音效
// ============================================

void playHit(int lane, int pitch) {

  if (!voicesReady) return;

  float frequency =
    440.0f * pow(2, (pitch - 69) / 12.0f);

  pulseVoices[lane].freq(frequency);
  triangleVoices[lane].freq(frequency);
  sawVoices[lane].freq(frequency);

  hitAt[lane] = millis();
}


void updateHitSound() {

  if (!voicesReady) return;

  for (int i = 0; i < 4; i++) {

    int age = millis() - hitAt[i];

    float env = 0;

    if (state == 2 &&
        age >= 0 &&
        age < 300) {

      env =
        min(1, age / 8.0f) *
        exp(-age / 125.0f) *
        0.28f *
        (musicVolume / 100.0f);
    }

    pulseVoices[i].amp(
      patchMode == 0 ? env : 0
    );

    triangleVoices[i].amp(
      patchMode == 1 ? env : 0
    );

    sawVoices[i].amp(
      patchMode == 2 ? env * 0.7f : 0
    );
  }
}


// ============================================
// 21. 敲擊判定與計分
// ============================================

void hitNote(int lane) {

  if (state != 2 ||
      lane < 0 ||
      lane >= 4) {
    return;
  }

  tapFlash[lane] = millis();

  int t = songTime();

  if (t < -HIT_WINDOW_MS) {

    lastGain = 0;
    showJudge("READY");

    return;
  }

  RhythmNote best = null;
  int bestDelta = 100000;

  for (RhythmNote n : notes) {

    if (n.done || n.lane != lane) {
      continue;
    }

    int diff = abs(n.hitTime - t);

    if (diff < bestDelta) {

      bestDelta = diff;
      best = n;
    }
  }

  if (best == null ||
      bestDelta > HIT_WINDOW_MS) {

    emptyTapCount++;

    judgeLane = lane;
    lastGain = 0;

    laneJudge[lane] = "EMPTY";
    laneJudgeTime[lane] = millis();

    showJudge("EMPTY");

    return;
  }

  best.done = true;

  if (bestDelta <= PERFECT_WINDOW_MS) {

    perfectCount++;
    score += 100;
    combo++;

    lastGain = 100;

    showJudge("PERFECT");

    laneJudge[lane] = "PERFECT";

  } else {

    goodCount++;
    score += 50;
    combo++;

    lastGain = 50;

    showJudge("GOOD");

    laneJudge[lane] = "GOOD";
  }

  judgeLane = lane;

  maxCombo = max(maxCombo, combo);

  laneJudgeTime[lane] = millis();
  hitFlash[lane] = millis();

  playHit(lane, best.pitch);
}


void showJudge(String s) {

  judgeText = s;
  judgeAt = millis();
}


// ============================================
// 22. 暫停功能
// ============================================

void togglePause() {

  if (state == 2) {

    pauseStart = millis();

    pauseTracks();

    state = 3;

    sendArduino('X');

  } else if (state == 3) {

    pausedTotal += millis() - pauseStart;

    resumeTracks();

    state = 2;
  }
}


void drawPause() {

  fill(5, 8, 20, 235);

  rect(110, 215, 740, 255, 8);

  stroke(#F872FA);
  noFill();

  rect(110, 215, 740, 255, 8);

  noStroke();

  textFont(arcadeFont);
  textSize(44);
  fill(#FFE16E);

  text("PAUSED", DESIGN_W/2, 293);

  fill(#00E9F4);

  rect(327, 340, 306, 57, 5);

  fill(#091021);
  textSize(21);

  text("RESUME  [SPACE]", DESIGN_W/2, 369);

  textSize(15);
  fill(#A6B8DF);

  text(
    "CLICK RESUME TO CONTINUE",
    DESIGN_W/2, 431
  );
}


// ============================================
// 23. 結算畫面
// ============================================

void finishGame() {

  bestScores[difficulty] =
    max(bestScores[difficulty], score);

  stopTracks();

  sendArduino('X');

  state = 4;
}


void drawResult() {

  titleBar();

  textFont(arcadeFont);
  textSize(42);
  fill(#81F797);

  text(
    "GAME OVER",
    DESIGN_W/2, 181
  );

  fill(#FFFFFF);
  textSize(27);

  text(
    "SCORE: " + score,
    DESIGN_W/2, 256
  );

  textSize(19);

  text(
    "PERFECT: " + perfectCount +
    "     GOOD: " + goodCount +
    "     MISS: " + missCount,
    DESIGN_W/2, 334
  );

  text(
    "MAX COMBO: " + maxCombo,
    DESIGN_W/2, 372
  );

  textSize(15);
  fill(#A6B8DF);

  text(
    "LEVEL " + difficultyNames[difficulty] +
    " / " + notes.size() + " NOTES",
    DESIGN_W/2, 304
  );

  
  // 顯示最高分數
  fill(#FFE16E);
  textSize(16);

  text(
    "BEST SCORE: " + bestScores[difficulty],
    DESIGN_W/2, 415
  );


  fill(#00E9F4);

  rect(309, 470, 342, 66, 7);

  fill(#091021);
  textSize(25);

  text(
    "RETRY  [ENTER]",
    DESIGN_W/2, 504
  );

  fill(#AAB9D9);
  textSize(15);

  text(
    "ENTER: RETRY  |  Q: CHANGE LEVEL",
    DESIGN_W/2, 577
  );

  text(
    "OR CLICK RETRY TO PLAY AGAIN",
    DESIGN_W/2, 607
  );
}


// ============================================
// 24. Arduino 接收
// ============================================

void serialEvent(Serial src) {

  String incoming =
    src.readStringUntil('\n');

  if (incoming == null) return;

  String msg = incoming.trim();
  println("Arduino 指令：" + msg);

  if (msg.equals("M0")) {

    patchMode = 0;

  } else if (msg.equals("M1")) {

    patchMode = 1;

  } else if (msg.equals("M2")) {

    patchMode = 2;

  } else if (msg.equals("B1")) {

    accompanimentEnabled = true;

  } else if (msg.equals("B0")) {

    accompanimentEnabled = false;

  } else if (msg.equals("K")) {

    if (state == 1 || state == 4) {
      startGame();
    } else {
      togglePause();
    }

  } else if (msg.startsWith("V")) {

    try {

      musicVolume = constrain(
        Integer.parseInt(msg.substring(1)),
        0, 100
      );

    } catch (Exception e) {

      println("Bad volume command: " + msg);
    }
  }

  if (assetsLoaded) {
    applyVolumes();
  }
}


void sendArduino(char cmd) {

  if (arduinoReady && port != null) {
    port.write(cmd);
  }
}


// ============================================
// 25. 鍵盤操作
// ============================================

void keyPressed() {

  if (initPhase < 4) return;

  println(
    "KEY=" + key +
    "  CODE=" + keyCode +
    "  STATE=" + state
  );

  // Enter：開始或重玩
  if (key == ENTER ||
      key == RETURN ||
      keyCode == 10 ||
      keyCode == 13) {

    if (state == 1 || state == 4) {
      startGame();
    }

    return;
  }

  // 空白鍵：暫停
  if (key == ' ') {

    togglePause();
    return;
  }

  // Q：難度
  if (key == 'q' || key == 'Q') {

    cycleDifficulty();
    return;
  }

  // 1、2、3：電子音色
  if (key >= '1' && key <= '3') {

    patchMode = key - '1';

    if (assetsLoaded) {
      applyVolumes();
    }

    return;
  }

  // B：伴奏
  if (key == 'b' || key == 'B') {

    accompanimentEnabled =
      !accompanimentEnabled;

    if (assetsLoaded) {
      applyVolumes();
    }

    return;
  }

  // 上下鍵：音量
  if (keyCode == UP || keyCode == DOWN) {

    musicVolume = constrain(
      musicVolume +
      (keyCode == UP ? 5 : -5),
      0, 100
    );

    if (assetsLoaded) {
      applyVolumes();
    }

    return;
  }

  if (state != 2) return;

  char pressed =
    Character.toLowerCase(key);

  int lane = -1;

  if (pressed == 'a' || keyCode == 65) {

    lane = 0;

  } else if (pressed == 's' || keyCode == 83) {

    lane = 1;

  } else if (pressed == 'd' || keyCode == 68) {

    lane = 2;

  } else if (pressed == 'f' || keyCode == 70) {

    lane = 3;
  }

  if (lane != -1) {

    println("按下軌道：" + lane);

    hitNote(lane);
  }
}


// ============================================
// 26. 滑鼠操作
// ============================================

void mousePressed() {

  if (initPhase < 4) return;

  float fitScale = min(
    width / (float)DESIGN_W,
    height / (float)DESIGN_H
  );

  if (fitScale <= 0) return;

  float offsetX =
    (width - DESIGN_W * fitScale) * 0.5f;

  float offsetY =
    (height - DESIGN_H * fitScale) * 0.5f;

  float x =
    (mouseX - offsetX) / fitScale;

  float y =
    (mouseY - offsetY) / fitScale;

  // 開始畫面
  if (state == 1) {

    if (inside(x, y, 310, 215, 340, 32)) {

      cycleDifficulty();
      return;
    }

    if (inside(x, y, 310, 345, 340, 64)) {

      startGame();
      return;
    }

    return;
  }

  // 結算畫面
  if (state == 4) {

    if (inside(x, y, 309, 470, 342, 66)) {
      startGame();
    }

    return;
  }

  // 暫停畫面
  if (state == 3) {

    if (inside(x, y, 327, 340, 306, 57)) {
      togglePause();
    }

    return;
  }

  if (state != 2) return;

  // 切換難度
  if (inside(x, y, 797, 510, 130, 69)) {

    cycleDifficulty();
    return;
  }

  // 暫停
  if (inside(x, y, 797, 204, 130, 49)) {

    togglePause();
    return;
  }

  // 點擊音符軌道
  if (x >= TRACK_X &&
      x < TRACK_X + TRACK_W * 4 &&
      y >= TRACK_TOP &&
      y <= TRACK_BOTTOM) {

    int lane = constrain(
      (int)((x - TRACK_X) / TRACK_W),
      0, 3
    );

    hitNote(lane);
  }
}


boolean inside(
  float x,
  float y,
  float bx,
  float by,
  float bw,
  float bh
) {

  return x >= bx &&
         x <= bx + bw &&
         y >= by &&
         y <= by + bh;
}


// ============================================
// 27. 音符類別
// ============================================

class RhythmNote {

  int lane;
  int hitTime;
  int pitch;

  boolean done = false;

  RhythmNote(
    int lane,
    int hitTime,
    int pitch
  ) {

    this.lane = lane;
    this.hitTime = hitTime;
    this.pitch = pitch;
  }
}


// ============================================
// 28. 關閉程式時清理資源
// ============================================

void dispose() {

  sendArduino('X');

  stopTracks();

  if (port != null) {
    port.stop();
  }

  if (voicesReady) {

    for (int i = 0; i < 4; i++) {

      if (pulseVoices[i] != null) {
        pulseVoices[i].stop();
      }

      if (triangleVoices[i] != null) {
        triangleVoices[i].stop();
      }

      if (sawVoices[i] != null) {
        sawVoices[i].stop();
      }
    }
  }
}
