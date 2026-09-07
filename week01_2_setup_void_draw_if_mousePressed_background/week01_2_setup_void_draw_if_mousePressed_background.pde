//week01_2_setup_void_draw_if_mousePressed_background
//想要多點互動(只是畫圖,有點無聊)
//像C,C++,Java,C#這些語言的語法
//File-Save As 另存新檔
void setup(){//準備設定的函式,做一次
  size(500,500);//視窗大小
 }
void draw(){//準備畫圖的函式,每秒60次
//如果mouse按下去,就讓背景紅色
  if(mousePressed) background(255, 0, 0);//red
  else background(0, 255, 0);//否則 綠色
}
