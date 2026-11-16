//week11_3_arduino_joystick_serial_map_0_255
//將要跟Processing 互溝通
void setup() {
  Serial.begin(9600);
  pinMode(2, INPUT_PULLUP);
}
int myAnalogRead(int pin){
  // 利用map()韓式,把0..1023對應0..255
  return map(analogRead(pin),0, 1023, 0, 255);
}
void loop() {
  delay(30);//要再慢一點
  Serial.write( myAnalogRead(A0) );
  Serial.write( myAnalogRead(A1) );
  if(digitalRead(2)==LOW)Serial.print("D");//Down按
  else Serial.print("U");//Up沒按
  //少個跳行println()改成print()
}
