//week07_4_processing_serial_audio_do_re_mi
//修改自week05_3_processing_audio_do_re_mi_draw
//修改自week07_3_processing_audio_do_re_mi(主要程式)
import processing.serial.*;
Serial myPort;//加這行!!!!
import processing.sound.*;
SoundFile Do, Re, Mi;//有3個變數 Do Re Mi
void setup(){
  size(300,200);
  myPort = new Serial(this,"COM3",9600);
  Do = new SoundFile(this,"do.wav");
  Re = new SoundFile(this,"re.wav");
  Mi = new SoundFile(this,"mi.wav");
}
void draw(){
  rect(0,0,100,200);
  rect(100,0,100,200);
  rect(200,0,100,200);
}
void mousePressed(){
  if(mouseX < 100){
    Do.play();
  }  else if(mouseX < 200){
    Re.play();
  }  else if(mouseX < 300){
    Mi.play();
  }
}
void mouseReleased(){
  myPort.write('0');
}
