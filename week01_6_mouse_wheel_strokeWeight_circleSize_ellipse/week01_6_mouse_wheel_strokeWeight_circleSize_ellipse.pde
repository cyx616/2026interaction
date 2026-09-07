//week01_6_mouse_wheel_strokeWeight_circleSize_ellipse
//整合week01_4 week01_5讓大小可以mouse wheel改變
float circleSize = 5;//小一點點
void setup(){
   size(500,500);
   background(255);//白色背景
}

void draw (){
  strokeWeight(circleSize);
  if(mousePressed){//mouse按下去,有兩種可能
    if(mouseButton == LEFT) stroke(0);//畫黑線
    if(mouseButton == RIGHT) stroke(255);//白色清掉
    line(mouseX, mouseY, pmouseX, pmouseY);
    }
    noStroke();//不要畫外框
    rect(0, 0, 100, 100);
    stroke(0);//黑色的線
    strokeWeight(1);//左上角小圈圈外框
    ellipse(50, 50, circleSize, circleSize);//畫出圈
}
void mouseWheel(MouseEvent e){
  circleSize = circleSize - e.getCount(); 
}
