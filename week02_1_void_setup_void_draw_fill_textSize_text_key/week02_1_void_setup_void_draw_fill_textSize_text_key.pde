//week02_1_void_setup_void_draw_fill_textSize_text_key
//鍵盤的操作,與上周的mouse結合
//File-Preference
void setup(){//設定函式
  size(500, 500);//視窗大小
}
void draw(){
  if(mousePressed)background(#2EE5CE);
  else background(#0AE4FA);//用Tool-Color選擇器
  fill(0, 0, 255);//藍色填充色
  textSize(80);//字的大小
  text("key: "+ key, 200, 300);//關注音輸入法,才能收 key
}
