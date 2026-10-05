//week_05_2_processing_do_re_mi_Serial_keyPressed_keyReleased
//修改自week_05_1_processing_do_re_mi_Serial
//按多久、較多久,放開就不叫了 不是永遠0.1秒
import processing.serial.*;//使用USB Serial外掛
Serial myPort;//將用myPort來傳USB Serial 資料
void setup() {
  size(300, 200);
  myPort = new Serial(this, "COM3", 9600);//中間"com4" or"COM3"
}
void draw() {
  
}
int p1 = 0, p2 = 0, p3 = 0;//變數紀錄按鍵,一開始沒按, 下面有做修改
void keyPressed(){
  if(p1==0 && key=='1')myPort.write('1');//之前沒按, 現在按下去了
  if(p2==0 && key=='2')myPort.write('2');
  if(p3==0 && key=='3')myPort.write('3');
  if(p1==0 && key=='1')p1 = 1;//0代表沒有按，1代表按下去
  if(p2==0 && key=='2')p2 = 1;
  if(p3==0 && key=='3')p3 = 1;
}
void keyReleased(){
  if(key=='1')p1 = 0;//放開 1 鍵 
  if(key=='2')p2 = 0;//放開 2 鍵 
  if(key=='3')p3 = 0;//放開 3 鍵 
  myPort.write('0');//告訴 Arduino 你不要發出任何聲音!!!!!
}
