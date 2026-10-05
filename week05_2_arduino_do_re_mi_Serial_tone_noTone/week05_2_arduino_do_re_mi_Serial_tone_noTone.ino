//week05_2_arduino_do_re_mi_Serial_tone_noTone
//修改自week05_1_arduino_do_re_mi_Serial
void setup() {
  Serial.begin(9600);//USB Serial開始傳輸,速度 9600 bps
  tone(8, 523, 100); delay(200);// Do 
  tone(8, 587, 100); delay(200);// Re 
  tone(8, 659, 100); delay(200);// Mi 
  tone(8, 587, 100); delay(200);// Re 
  tone(8, 523, 100); delay(200);// Do 
}
char c = '0';//0:不要發聲音 1:Do 2:Re 3:Mi
void loop() {
  if(Serial.available()){//如果USB Serial 有收到資料
    c = Serial.read();//就讀進來(不要再宣告變數char c,直接寫 c)
  }
   if(c=='0')noTone(8);//不要發聲音
   if(c=='1') tone(8, 523, 100);//Do 1秒
   if(c=='2') tone(8, 587, 100);//Re 1秒
   if(c=='3') tone(8, 659, 100);//Mi 1秒
}
