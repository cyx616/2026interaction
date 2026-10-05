//week05_1_arduino_do_re_mi_Serial
//在啟動時 void setup()裡,多了 Do Re MI 才知道小板子有開機運作 
//修改自week02_5_arduino_tone_do_re_mi_Serial_begin_available_read_if_tone
//我想把Arduino跟Processing 結合
//在Processing 按下key 1 2 3 對應Arduino 的 Do Re Mi 使用USB Serial
void setup() {
  Serial.begin(9600);//USB Serial開始傳輸,速度 9600 bps
  tone(8, 523, 100);// Do 0.1秒
  delay(200);//等一下聲音出來, 不要滑過去
  tone(8, 587, 100);// Re 0.1秒
  delay(200);//等一下聲音出來, 不要滑過去
  tone(8, 659, 100);// Mi 0.1秒
}

void loop() {
  if(Serial.available()){//如果USB Serial 有收到資料
    char c = Serial.read();//就讀進來
    if(c=='1') tone(8, 523, 100);//Do 1秒
    if(c=='2') tone(8, 587, 100);//Re 1秒
    if(c=='3') tone(8, 659, 100);//Mi 1秒
  }
}
