//week11_1_arduino_joystick_analogRead_A0_A1_tone
//要把joysyick的A0、A1接起來,讀資料, 很吵的輸出聲音
void setup(){
  
}
void loop(){
  int x = analogRead(A0);
  int y = analogRead(A1);
  tone(8,x);//會把x 的值,直接很吵的輸出
  //如果太吵、想暫時停止,把 MakerUno 的跳針往左推
}
