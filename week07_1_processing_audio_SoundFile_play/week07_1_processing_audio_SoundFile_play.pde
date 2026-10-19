//week07_1_processing_audio_SoundFile_play
//File-Preference...把字型調大
//想要在電腦,用程式控制聲音/音樂的輸入
//方法1:Processing 的 Sound 外掛,方法2:Minim的外掛
//Sketch - Library - Manage Libraries...網路通的話可下載
//或者用google:processing sound library download
//Moodle的 {上課用軟體} 也有一份sound.zip
//把{有3個資料夾}的sound放在{文件-Processing-Libraries}
//成功後,便可在Files-Example-Libraries核心函式庫-Sound-SoundFile-JumbleSoundfile

import processing.sound.*;//使用外掛
SoundFile sound;//宣告變數
void setup(){
  size(300,300);
  sound = new SoundFile(this,"music.mp3");
  sound.play();//準備好music.mp3,拉到程式裡,播放
 }
 void draw(){
   
 }
