//week09_1_arduino_ai_MakerUNO_PCM_D8
//想要讓MakerUNO發出更多元的聲音,不要只是單調的tone()
//老師要示範,用AI一步步找出答案
//Q1:MakerUNO本身可以用pin 8 的 buzzer利用tone()來發出單調的聲音。
//有辦法發出比較精彩的聲音嗎? ex. wav or mp3
//(註:老師教AI要10問10達、百問百答,所以現在要一步步練習問、互動,找到答案)
//Q2:請幫我找PCM相關的Libraries 我想試試看
//Q3如何修改PCM LIbrary，讓他可以利用pin 8的軟體或其他輸出技術播放PCM?
//這時,AI給我們修改後的MakerUNO_PCM_D8.zip解開來,把MakerUNO_PCM_D8.ino複製
//Q4:我在邊一時,出現 PCM_D8.zip的錯誤,訊息如下...
//A:請把PCM.cpp PCM.h sounddata.h都放在你的目錄 week09_1_arduino_ai_makerUNO_PCM_D8

// Maker UNO: turn ON the onboard BUZZER slide switch.
// Board selection: Arduino Uno / ATmega328P / 16 MHz.
// This sketch uses the local modified PCM.cpp, NOT the original D11 library.
#include "PCM.h"
#include "sounddata.h"

void setup() {
  startPlayback(sounddata_data, sounddata_length);
}

void loop() {
  // One-shot sample plays for 1 second. Press RESET to play again.
}
