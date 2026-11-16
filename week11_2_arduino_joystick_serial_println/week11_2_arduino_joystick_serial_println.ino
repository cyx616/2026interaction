/*
// week11_2_arduino_joystick_serial_println
//這個會用Arduino右上角Serial Monitor序列埠監控視窗(會占用USB)
void setup() {
  Serial.begin(9600);
  pinMode(2, INPUT_PULLUP);  // 再加這行
}

void loop() {
  int x = analogRead(A0);  // 讀入 x 座標
  int y = analogRead(A1);  // 讀入 y 座標
  int sw = digitalRead(2); // joystick 壓鈕

  if (digitalRead(2) == LOW) sw = 1;  // 按下去，設1
  else sw = 0;// 彈起來，設0

  char line[200];
  sprintf(line, "x:%3d y:%3d sw:%d\n", x, y, sw);
  Serial.print(line);  // 改用 print() 不要 println()
}
*/
// week11_3_processing_joystick_serial_?????
// 要把 Arduino 的資料，用 USB 讀入（要記得關 Arduino
// 使用 USB 的 Serial 的資料

import processing.serial.*;

Serial myPort;

void setup() {
  size(512, 512);
  myPort = new Serial(this, "COM4", 9600);
}

int x = 0, y = 0, sw = 0;

void draw() {
  background(255);

  if (myPort.available() >= 3) {  // 亂碼、亂碼、U/D
    x = (int) myPort.read();
    y = (int) myPort.read();
    sw = (int) myPort.read();
    //myPort.read();
  }

  ellipse(x+128, y+128, 8, 8);
}
