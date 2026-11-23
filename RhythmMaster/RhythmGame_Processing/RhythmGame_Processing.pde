
import processing.sound.*;
import processing.serial.*;
import java.util.ArrayList;

// =====================================
// 音樂節奏挑戰 - 淺藍色版本
// Processing 4.3 + Maker UNO
//
// Enter：開始遊戲 / 重新挑戰
// A S D F：擊打音符
// Space：暫停 / 繼續
//
// 音樂：data/music.mp3
// =====================================

// 音樂
SoundFile music;
Amplitude analyzer;

// Maker UNO
Serial myPort;
boolean arduinoReady = false;

// 遊戲狀態
// 0 = 音樂載入失敗
// 1 = 準備開始
// 2 = 遊戲中
// 3 = 暫停
// 4 = 遊戲結束
int state = 0;

// =====================================
// 淺藍色主題
// =====================================

color bgColor = #EAF7FF;
color panelColor = #D9F0FF;
color panelBorderColor = #B9DDF2;

color titleColor = #4A90C2;
color mainTextColor = #3B6F91;
color subTextColor = #6E9FBE;

color hitLineColor = #4A9DD8;
color perfectColor = #2387BC;
color goodColor = #598FC5;
color missColor = #C77B91;

char[] keys = {'a', 's', 'd', 'f'};

color[] laneColors = {
  #8ED8F8,
  #CDB4F6,
  #FFD6A5,
  #B7EFC5
};

// =====================================
// 遊戲設定
// =====================================

float hitY = 465;

int travelTime = 1600;
int noteInterval = 550;

ArrayList<RhythmNote> notes =
  new ArrayList<RhythmNote>();

int gameStart = 0;
int pauseStart = 0;
int pausedTotal = 0;
int lastNoteTime = 0;

// 成績
int score = 0;
int combo = 0;
int maxCombo = 0;

int perfectCount = 0;
int goodCount = 0;
int missCount = 0;

// 判定顯示
String judgeText = "";
int judgeTime = -9999;

// 按鍵視覺回饋
int[] keyFlashTime = {
  -9999, -9999, -9999, -9999
};

// 流水燈
int lastLedSend = 0;
float smoothLevel = 0;
float peakLevel = 0.02;

String songName = "music.mp3";

// =====================================
// 1. 初始化
// =====================================

void setup() {
  size(800, 620);
  frameRate(60);
  textAlign(CENTER, CENTER);

  // Windows 中文字型
  PFont chineseFont =
    createFont("Microsoft JhengHei", 32);

  textFont(chineseFont);

  // 尋找 Maker UNO 序列埠
  String[] ports = Serial.list();
  printArray(ports);

  String chosenPort = "";

  // 優先尋找 COM3
  for (int i = 0; i < ports.length; i++) {
    if (ports[i].equalsIgnoreCase("COM3")) {
      chosenPort = ports[i];
      break;
    }
  }

  // 沒有 COM3 則嘗試第一個
  if (chosenPort.equals("") &&
      ports.length > 0) {
    chosenPort = ports[0];
  }

  if (!chosenPort.equals("")) {
    try {
      myPort = new Serial(
        this, chosenPort, 9600
      );

      arduinoReady = true;

      println("Arduino Port: " + chosenPort);

      sendArduino('X');

    } catch (RuntimeException e) {
      arduinoReady = false;
      println("Arduino connection failed");
    }
  }

  loadMusic();
}

// =====================================
// 2. 自動載入音樂
// =====================================

void loadMusic() {
  try {
    if (music != null) {
      music.stop();
    }

    music = new SoundFile(
      this, "music.mp3"
    );

    analyzer = new Amplitude(this);
    analyzer.input(music);

    songName = "music.mp3";
    state = 1;

    println("Music loaded: " + songName);

  } catch (Exception e) {
    music = null;
    state = 0;

    println(
      "Music load error: " +
      e.getMessage()
    );
  }
}

// =====================================
// 3. 畫面控制
// =====================================

void draw() {
  background(bgColor);

  if (state == 0) {
    showMenu(
      "找不到音樂檔案",
      "請確認 data/music.mp3"
    );
  }

  else if (state == 1) {
    showMenu(
      "音樂節奏挑戰",
      "按 Enter 鍵開始遊戲"
    );

    fill(subTextColor);
    textSize(18);
    text(
      "目前歌曲：" + songName,
      width/2, 390
    );
  }

  else if (state == 2 || state == 3) {

    if (state == 2) {
      updateGame();

      if (state == 2) {
        updateMusicLights();
      }
    }

    if (state == 4) {
      showResult();
    } else {
      drawGame();

      if (state == 3) {
        drawPause();
      }
    }
  }

  else if (state == 4) {
    showResult();
  }
}

// =====================================
// 4. 開始畫面
// =====================================

void showMenu(
  String title,
  String subtitle
) {
  fill(titleColor);
  textSize(42);
  text(title, width/2, 190);

  fill(mainTextColor);
  textSize(24);
  text(subtitle, width/2, 285);

  fill(subTextColor);
  textSize(19);
  text(
    "使用 A、S、D、F 鍵擊打音符",
    width/2, 335
  );

  textSize(17);
  text(
    "遊戲前請切換為英文輸入法",
    width/2, 465
  );
}

// =====================================
// 5. 開始遊戲
// =====================================

void startGame() {
  if (music == null) return;

  notes.clear();

  score = 0;
  combo = 0;
  maxCombo = 0;

  perfectCount = 0;
  goodCount = 0;
  missCount = 0;

  judgeText = "";
  judgeTime = -9999;

  for (int i = 0; i < 4; i++) {
    keyFlashTime[i] = -9999;
  }

  int durationMs =
    int(music.duration() * 1000);

  int endTime =
    min(45000, durationMs - 500);

  // 每隔 550ms 產生音符
  for (int t = 2000;
       t < endTime;
       t += noteInterval) {

    int i = notes.size();

    int lane =
      (i * 7 + i / 4) % 4;

    notes.add(
      new RhythmNote(lane, t)
    );
  }

  if (notes.size() > 0) {
    lastNoteTime =
      notes.get(
        notes.size() - 1
      ).hitTime;
  } else {
    lastNoteTime = 0;
  }

  pausedTotal = 0;
  gameStart = millis();

  smoothLevel = 0;
  peakLevel = 0.02;
  lastLedSend = 0;

  music.stop();
  music.cue(0);
  music.play();

  state = 2;

  println("Game Started!");
}

// =====================================
// 6. 遊戲時間
// =====================================

int gameTime() {
  if (state == 3) {
    return pauseStart -
      gameStart - pausedTotal;
  }

  return millis() -
    gameStart - pausedTotal;
}

// =====================================
// 7. 更新遊戲
// =====================================

void updateGame() {
  int t = gameTime();

  for (RhythmNote n : notes) {
    if (!n.done &&
        t > n.hitTime + 250) {

      n.done = true;
      missCount++;
      combo = 0;

      setJudge("失誤");
    }
  }

  if (t > lastNoteTime + 650) {
    finishGame();
  }
}

// =====================================
// 8. 繪製遊戲畫面
// =====================================

void drawGame() {
  int t = gameTime();

  background(bgColor);

  // 分數
  fill(mainTextColor);
  textSize(26);

  text(
    "分數：" + score,
    170, 38
  );

  text(
    "連擊：" + combo,
    610, 38
  );

  // 四條跑道
  for (int i = 0; i < 4; i++) {
    float x = 160 + i * 120;

    stroke(panelBorderColor);
    strokeWeight(2);
    fill(panelColor);

    rect(x, 75, 116, 440, 12);
    noStroke();

    // 按鍵時短暫發亮
    if (state == 2 &&
        millis() - keyFlashTime[i] < 110) {

      fill(laneColors[i], 105);
      rect(x, 75, 116, 440, 12);
    }

    fill(mainTextColor);
    textSize(32);

    text(
      str(keys[i]).toUpperCase(),
      x + 58, 550
    );
  }

  // 判定線
  stroke(hitLineColor);
  strokeWeight(5);

  line(
    160, hitY,
    636, hitY
  );

  noStroke();

  // 繪製下落音符
  for (RhythmNote n : notes) {
    if (n.done) continue;

    float remain =
      n.hitTime - t;

    float y = hitY -
      remain *
      (hitY - 85) / travelTime;

    if (y >= 75 && y <= 510) {
      float x =
        160 + n.lane * 120;

      // 音符陰影
      fill(130, 170, 195, 55);

      rect(
        x + 12,
        y - 9,
        98, 26, 10
      );

      // 音符本體
      fill(laneColors[n.lane]);

      rect(
        x + 9,
        y - 13,
        98, 26, 10
      );
    }
  }

  // 顯示命中判定
  if (millis() - judgeTime < 450) {
    if (judgeText.equals("完美")) {
      fill(perfectColor);
    }
    else if (judgeText.equals("良好")) {
      fill(goodColor);
    }
    else {
      fill(missColor);
    }

    textSize(35);
    text(
      judgeText,
      width/2, 590
    );
  }
}

// =====================================
// 9. 擊打音符判定
// =====================================

void hitNote(int lane) {
  int t = gameTime();

  RhythmNote nearest = null;
  int bestDiff = 99999;

  for (RhythmNote n : notes) {
    if (n.done ||
        n.lane != lane) {
      continue;
    }

    int diff =
      abs(t - n.hitTime);

    if (diff < bestDiff) {
      bestDiff = diff;
      nearest = n;
    }
  }

  // 沒擊中
  if (nearest == null ||
      bestDiff > 250) {

    combo = 0;
    setJudge("失誤");

    println("MISS");

    return;
  }

  // 完美
  if (bestDiff <= 100) {
    score += 100;
    perfectCount++;
    combo++;

    nearest.done = true;
    setJudge("完美");

    println("PERFECT +100");
  }

  // 良好
  else {
    score += 50;
    goodCount++;
    combo++;

    nearest.done = true;
    setJudge("良好");

    println("GOOD +50");
  }

  maxCombo = max(maxCombo, combo);
}

// =====================================
// 10. 判定文字
// =====================================

void setJudge(String s) {
  judgeText = s;
  judgeTime = millis();
}

// =====================================
// 11. Maker UNO 流水燈
// =====================================

void updateMusicLights() {
  if (analyzer == null) return;

  if (millis() - lastLedSend < 70) {
    return;
  }

  lastLedSend = millis();

  float level =
    analyzer.analyze();

  smoothLevel =
    smoothLevel * 0.65 +
    level * 0.35;

  peakLevel = max(
    0.015,
    max(
      smoothLevel,
      peakLevel * 0.997
    )
  );

  float normalized =
    constrain(
      smoothLevel / peakLevel,
      0, 1
    );

  int ledLevel =
    int(normalized * 9);

  if (arduinoReady) {
    myPort.write(
      "L" + ledLevel + "\n"
    );
  }
}

// =====================================
// 12. Arduino 通訊
// =====================================

void sendArduino(char command) {
  if (arduinoReady &&
      myPort != null) {
    myPort.write(command);
  }
}

// =====================================
// 13. 暫停畫面
// =====================================

void drawPause() {
  noStroke();
  fill(255, 255, 255, 190);

  rect(
    0, 0,
    width, height
  );

  fill(titleColor);
  textSize(48);

  text(
    "遊戲暫停",
    width/2,
    height/2
  );

  fill(mainTextColor);
  textSize(21);

  text(
    "按空白鍵繼續",
    width/2,
    height/2 + 65
  );
}

// =====================================
// 14. 結束遊戲
// =====================================

void finishGame() {
  state = 4;

  if (music != null) {
    music.stop();
  }

  sendArduino('X');
}

// =====================================
// 15. 結算畫面
// =====================================

void showResult() {
  background(bgColor);

  fill(titleColor);
  textSize(42);

  text(
    "遊戲結束",
    400, 105
  );

  fill(mainTextColor);
  textSize(38);

  text(
    "總分：" + score,
    400, 190
  );

  textSize(25);

  text(
    "完美命中：" + perfectCount,
    400, 260
  );

  text(
    "良好命中：" + goodCount,
    400, 305
  );

  text(
    "失誤次數：" + missCount,
    400, 350
  );

  text(
    "最高連擊：" + maxCombo,
    400, 395
  );

  fill(subTextColor);
  textSize(20);

  text(
    "按 Enter 鍵重新挑戰",
    400, 490
  );
}

// =====================================
// 16. 鍵盤操作
// =====================================

void keyPressed() {

  // Enter 開始
  // 額外支援 P 作為備用
  if (keyCode == 10 ||
      keyCode == 13 ||
      key == ENTER ||
      key == RETURN ||
      key == 'p' ||
      key == 'P') {

    if (state == 1 || state == 4) {
      startGame();
    }

    return;
  }

  // Space 暫停 / 繼續
  if (key == ' ') {

    if (state == 2) {
      pauseStart = millis();

      music.pause();
      state = 3;

      sendArduino('X');
    }

    else if (state == 3) {
      pausedTotal +=
        millis() - pauseStart;

      music.play();
      state = 2;
    }

    return;
  }

  if (state != 2) return;

  char k =
    Character.toLowerCase(key);

  // A S D F 按鍵
  for (int i = 0; i < 4; i++) {
    if (k == keys[i]) {

      keyFlashTime[i] = millis();

      // Maker UNO 按鍵音效
      sendArduino(k);

      // 判斷是否擊中
      hitNote(i);

      break;
    }
  }
}

// =====================================
// 17. 音符類別
// =====================================

class RhythmNote {
  int lane;
  int hitTime;

  boolean done = false;

  RhythmNote(int l, int t) {
    lane = l;
    hitTime = t;
  }
}

// =====================================
// 18. 關閉程式
// =====================================

void dispose() {
  sendArduino('X');

  if (myPort != null) {
    myPort.stop();
  }

  if (music != null) {
    music.stop();
  }
}
