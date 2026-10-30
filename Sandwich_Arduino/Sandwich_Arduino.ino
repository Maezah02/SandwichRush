int xyzPins[] = {39, 32, 2};
int potPin = 13;


void setup() {
 Serial.begin(9600);
 pinMode(xyzPins[2], INPUT_PULLUP);
}


void loop() {
 int xVal = analogRead(xyzPins[0]);
 int yVal = analogRead(xyzPins[1]);
 int zVal = digitalRead(xyzPins[2]);
 int potValue = analogRead(potPin);


 Serial.printf("%d,%d,%d,%d", xVal, yVal, zVal, potValue);
 Serial.println();


 delay(100);
