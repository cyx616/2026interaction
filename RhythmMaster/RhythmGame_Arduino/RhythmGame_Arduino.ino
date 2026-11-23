
// =====================================
// RhythmMaster - Arduino Maker UNO
// Version 2.0：加入搖桿控制
// =====================================

// ===== LED 設定 =====
const byte ledPins[] = {
  3, 4, 5, 6, 7,
  9, 10, 11, 12, 13
};

const int ledCount = 10;
const int buzzerPin = 8;

// ===== 原始音樂控制變數 =====
int musicLevel = 0;
int ledPosition = 0;

bool lightEnabled = false;
bool waitingLevel = false;

unsigned long lastMove = 0;

// ===== 搖桿設定 =====
const int joyX = A0;
const int joyY = A1;
const int joySW = A2;

// 搖桿讀取數值
int joyXValue = 0;
int joyYValue = 0;

// 按鈕狀態
bool lastButtonState = HIGH;
bool buttonReading = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 40;

// 智慧伴奏開關
bool accompanimentEnabled = false;

// 音量控制（0～100）
int musicVolume = 50;

// 模式控制
int musicMode = 1;

// 搖桿控制狀態
int lastMode = -1;
bool volumeReady = true;


// =====================================
// SETUP
// =====================================

void setup() {

  Serial.begin(9600);

  pinMode(buzzerPin, OUTPUT);

  // 設定搖桿按鈕
  pinMode(joySW, INPUT_PULLUP);

  // 設定 LED
  for (int i = 0; i < ledCount; i++) {
    pinMode(ledPins[i], OUTPUT);
    digitalWrite(ledPins[i], LOW);
  }

}


// =====================================
// LOOP
// =====================================

void loop() {

  // 讀取 Processing 傳來的指令
  while (Serial.available() > 0) {

    char c = Serial.read();

    if (c == 'L') {
      waitingLevel = true;
    }

    else if (waitingLevel &&
             c >= '0' && c <= '9') {

      musicLevel = c - '0';
      lightEnabled = true;
      waitingLevel = false;
    }

    else if (c == 'X') {

      lightEnabled = false;
      waitingLevel = false;

      clearLights();
      noTone(buzzerPin);
    }

    // A S D F 四種音效
    else if (c == 'a') {
      tone(buzzerPin, 523, 110);
    }

    else if (c == 's') {
      tone(buzzerPin, 587, 110);
    }

    else if (c == 'd') {
      tone(buzzerPin, 659, 110);
    }

    else if (c == 'f') {
      tone(buzzerPin, 784, 110);
    }

    // PERFECT
    else if (c == 'P') {
      tone(buzzerPin, 1200, 150);
    }

    // GOOD
    else if (c == 'G') {
      tone(buzzerPin, 900, 120);
    }
  }

  // 讀取搖桿
  readJoystick();

  // 原本 LED 流水燈功能
  if (!lightEnabled) return;

  int speedTime =
    map(musicLevel, 0, 9, 180, 45);

  if (millis() - lastMove >=
      (unsigned long)speedTime) {

    lastMove = millis();

    ledPosition++;

    if (ledPosition >= ledCount) {
      ledPosition = 0;
    }

    showFlow();
  }

}


// =====================================
// 搖桿讀取功能
// =====================================

void readJoystick() {

  joyXValue = analogRead(joyX);
  joyYValue = analogRead(joyY);

  // ===== 左右控制：切換模式 =====

  if (joyXValue < 300) {
    musicMode = 0;
  }

  else if (joyXValue > 700) {
    musicMode = 2;
  }

  else if (joyXValue > 400 &&
           joyXValue < 600) {
    musicMode = 1;
  }

  // 模式改變時才傳送
  if (musicMode != lastMode) {

    Serial.print("M");
    Serial.println(musicMode);

    lastMode = musicMode;
  }


  // ===== 上下控制：調整音量 =====

  if (joyYValue < 300 && volumeReady) {

    musicVolume += 5;

    musicVolume = constrain(
      musicVolume, 0, 100
    );

    sendVolume();

    volumeReady = false;
  }

  else if (joyYValue > 700 && volumeReady) {

    musicVolume -= 5;

    musicVolume = constrain(
      musicVolume, 0, 100
    );

    sendVolume();

    volumeReady = false;
  }

  // 回到中心後才能再次調整
  if (joyYValue > 400 &&
      joyYValue < 600) {

    volumeReady = true;
  }


  // ===== 按壓搖桿：開關智慧伴奏 =====

  bool reading = digitalRead(joySW);

  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > debounceDelay) {

    if (reading != buttonReading) {

      buttonReading = reading;

      if (buttonReading == LOW) {

        accompanimentEnabled =
          !accompanimentEnabled;

        if (accompanimentEnabled) {
          Serial.println("B1");
        }

        else {
          Serial.println("B0");
        }
      }
    }
  }

  lastButtonState = reading;

}


// =====================================
// 傳送音量資料給 Processing
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

  int lightCount = 1 + musicLevel / 3;

  for (int i = 0; i < lightCount; i++) {

    int index =
      (ledPosition - i + ledCount) % ledCount;

    digitalWrite(ledPins[index], HIGH);
  }

}


// =====================================
// 清除 LED
// =====================================

void clearLights() {

  for (int i = 0; i < ledCount; i++) {

    digitalWrite(ledPins[i], LOW);

  }

}
