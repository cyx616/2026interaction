//week02_5_arduino_tone_do_re_mi_Serial_begin_available_read_if_tone
//我想把Arduino跟Processing 結合
//在Processing 按下key 1 2 3 對應Arduino 的 Do Re Mi 使用USB Serial
void setup() {
  Serial.begin(9600);//USB Serial開始傳輸,速度 9600 bps
}

void loop() {
  if(Serial.available()){//如果USB Serial 有收到資料
    char c = Serial.read();//就讀進來
    if(c=='1') tone(8, 523, 1000);//Do 1秒
    if(c=='2') tone(8, 587, 1000);//Re 1秒
    if(c=='3') tone(8, 659, 1000);//Mi 1秒
  }
}
