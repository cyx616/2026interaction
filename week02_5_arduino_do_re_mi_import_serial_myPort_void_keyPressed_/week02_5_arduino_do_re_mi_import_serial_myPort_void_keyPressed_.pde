//week02_5_arduino_do_re_mi_import_serial_myPort_void_keyPressed_write
//我想把Arduino跟Processing 結合
//在Processing 按下key 1 2 3 對應Arduino 的 Do Re Mi 使用USB Serial
import processing.serial.*;//使用USB Serial外掛
Serial myPort;//將用myPort來傳USB Serial 資料
void setup() {
  size(300,200);
  myPort = new Serial(this,"COM3",9600);
}
void draw(){
}
void keyPressed() {
    if(key =='1') myPort.write('1');
    if(key =='2') myPort.write('2');
    if(key =='3') myPort.write('3');
  }
