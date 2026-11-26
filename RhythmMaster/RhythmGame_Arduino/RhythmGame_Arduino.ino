
/*
  =====================================
  音速節拍 - RhythmMaster
  Arduino Maker UNO

  功能：
  1. 左右搖桿：切換電子音色
  2. 上下搖桿：持續調整音量
  3. 搖桿按壓：開啟 / 關閉伴奏
  4. 保留 LED 流水燈

  注意：
  目前測試顯示按壓觸發 D2。
  因此這版使用 D2 作為伴奏開關。

  遊戲開始 / 暫停：
  由 Processing 鍵盤控制。
  =====================================
*/

// =====================================
// LED 設定
// =====================================

const byte ledPins[] = {
  3, 4, 5, 6, 7,
  9, 10, 11, 12, 13
};

const int ledCount = 10;
const int buzzerPin = 8;

int musicLevel = 0;
int ledPosition = 0;

bool lightEnabled = false;
bool waitingLevel = false;

unsigned long lastMove = 0;


// =====================================
// 搖桿腳位設定
// =====================================

// 左右方向
const int joyX = A0;

// 上下方向
const int joyY = A1;

// 目前按壓測試實際觸發 D2
// 因此將 D2 設為電子伴奏開關
const byte accompanimentButtonPin = 2;


// =====================================
// 電子音樂控制
// =====================================

// 三種音色：0、1、2
int musicMode = 0;
int lastMode = -1;

// 是否允許再次切換音色
bool modeReady = true;

// 音量 0~100
int musicVolume = 60;

// 電子伴奏狀態
bool accompanimentEnabled = true;


// =====================================
// 持續音量控制
// =====================================

// 上次調整方向
int lastVolumeDirection = 0;

// 上次調整時間
unsigned long lastVolumeAdjustTime = 0;

// 每150毫秒調整一次
const unsigned long volumeInterval = 150;

// 每次調整2%
const int volumeStep = 2;


// =====================================
// 按鈕防彈跳設定
// =====================================

bool lastButtonRaw = HIGH;
bool stableButton = HIGH;

unsigned long lastButtonChange = 0;

const unsigned long debounceDelay = 40;


// =====================================
// 函式宣告
// =====================================

void readJoystick();
void readAccompanimentButton();
void sendVolume();
void showFlow();
void clearLights();


// =====================================
// SETUP
// =====================================

void setup() {

  Serial.begin(9600);

  // 蜂鳴器
  pinMode(buzzerPin, OUTPUT);

  // D2 按鈕
  pinMode(
    accompanimentButtonPin,
    INPUT_PULLUP
  );

  // LED 初始化
  for (int i = 0; i < ledCount; i++) {

    pinMode(ledPins[i], OUTPUT);

    digitalWrite(
      ledPins[i],
      LOW
    );
  }
}


// =====================================
// LOOP
// =====================================

void loop() {

  // 接收 Processing 的 LED 指令
  while (Serial.available() > 0) {

    char c = Serial.read();

    // LED 亮度指令開頭
    if (c == 'L') {

      waitingLevel = true;
    }

    // 接收亮度數值 0~9
    else if (
      waitingLevel &&
      c >= '0' &&
      c <= '9'
    ) {

      musicLevel = c - '0';

      lightEnabled = true;
      waitingLevel = false;
    }

    // 停止 LED
    else if (c == 'X') {

      lightEnabled = false;
      waitingLevel = false;

      clearLights();

      noTone(buzzerPin);
    }
  }

  // 讀取左右與上下搖桿
  readJoystick();

  // 讀取按壓伴奏開關
  readAccompanimentButton();

  // 保留原本 LED 流水燈
  if (!lightEnabled) {
    return;
  }

  int speedTime =
    map(musicLevel, 0, 9, 180, 45);

  if (
    millis() - lastMove >=
    (unsigned long)speedTime
  ) {

    lastMove = millis();

    ledPosition++;

    if (ledPosition >= ledCount) {
      ledPosition = 0;
    }

    showFlow();
  }
}


// =====================================
// 搖桿控制
// =====================================

void readJoystick() {

  int joyXValue = analogRead(joyX);
  int joyYValue = analogRead(joyY);


  // ===================================
  // 左右控制：切換電子音色
  // ===================================

  // 向左：上一種音色
  if (
    modeReady &&
    joyXValue < 300
  ) {

    musicMode =
      (musicMode + 2) % 3;

    modeReady = false;
  }

  // 向右：下一種音色
  else if (
    modeReady &&
    joyXValue > 700
  ) {

    musicMode =
      (musicMode + 1) % 3;

    modeReady = false;
  }

  // 回到中央才能再次切換
  if (
    joyXValue > 420 &&
    joyXValue < 600
  ) {

    modeReady = true;
  }

  // 音色改變才傳送
  if (musicMode != lastMode) {

    Serial.print("M");
    Serial.println(musicMode);

    lastMode = musicMode;
  }


  // ===================================
  // 上下控制：持續調整音量
  // ===================================

  int volumeDirection = 0;

  // 向上：增加音量
  if (joyYValue < 300) {

    volumeDirection = 1;
  }

  // 向下：減少音量
  else if (joyYValue > 700) {

    volumeDirection = -1;
  }

  // 搖桿回到中央，停止調整
  if (volumeDirection == 0) {

    lastVolumeDirection = 0;

  } else {

    // 新方向立即調整一次
    // 持續推住每150ms調整一次
    if (
      volumeDirection != lastVolumeDirection ||
      millis() - lastVolumeAdjustTime >= volumeInterval
    ) {

      int oldVolume = musicVolume;

      musicVolume +=
        volumeDirection * volumeStep;

      // 限制音量在 0~100
      musicVolume = constrain(
        musicVolume,
        0,
        100
      );

      // 只有數值改變才傳送
      if (musicVolume != oldVolume) {

        sendVolume();
      }

      lastVolumeAdjustTime = millis();

      lastVolumeDirection =
        volumeDirection;
    }
  }
}


// =====================================
// 搖桿按壓：電子伴奏開關
// =====================================

void readAccompanimentButton() {

  bool reading =
    digitalRead(accompanimentButtonPin);

  // 偵測按鈕狀態變化
  if (reading != lastButtonRaw) {

    lastButtonChange = millis();
  }

  // 防彈跳處理
  if (
    millis() - lastButtonChange >
    debounceDelay
  ) {

    if (reading != stableButton) {

      stableButton = reading;

      // 只在按下瞬間切換
      if (stableButton == LOW) {

        accompanimentEnabled =
          !accompanimentEnabled;

        // 開啟伴奏
        if (accompanimentEnabled) {

          Serial.println("B1");

        }

        // 關閉伴奏
        else {

          Serial.println("B0");

        }
      }
    }
  }

  lastButtonRaw = reading;
}


// =====================================
// 傳送音量給 Processing
// =====================================

void sendVolume() {

  Serial.print("V");

  Serial.println(musicVolume);
}


// =====================================
// LED 流水燈
// =====================================

void showFlow() {

  clearLights();

  int lightCount =
    1 + musicLevel / 3;

  for (int i = 0; i < lightCount; i++) {

    int index =
      (ledPosition - i + ledCount)
      % ledCount;

    digitalWrite(
      ledPins[index],
      HIGH
    );
  }
}


// =====================================
// 清除所有 LED
// =====================================

void clearLights() {

  for (int i = 0; i < ledCount; i++) {

    digitalWrite(
      ledPins[i],
      LOW
    );
  }
}
