
import processing.serial.*;

Serial myPort;
int ButtonState = 1;

PImage kitchen;
PImage chef;
PImage bread;
PImage breadSandwich;

PImage youWin;
PImage youLose;
PImage heart;
PImage resultImage = null;

// All ingredients
String[] ingredients = {
  "tomato",
  "cucumber",
  "lettuce",
  "cheese",
  "egg",
  "mushroom",
  "onion",
  "avocado",
  "bacon",
  "ham"
};

// Random recipe with 4 ingredients
String[] recipe = new String[4];

// Ingredient images
PImage[] fallingImages = new PImage[10];
PImage[] sandwichImages = new PImage[10];

// Falling ingredients
ArrayList<FallingIngredient> fallingIngredients =
  new ArrayList<FallingIngredient>();

// Ingredients successfully caught
ArrayList<Integer> collected = new ArrayList<Integer>();

float chefX = 400;
float fallSpeed = 50;
float breadY = 525;
float bready = 60;

// Ingredient sizes
int fallingWidth = 65;
int fallingHeight = 65;

int sandwichWidth = 130;
int sandwichHeight = 42;
int topBreadWidth = 140;

// Distance between stacked ingredients
int stackSpacing = 10;

int nextDropTime = 0;

boolean breadFalling = false;
boolean breadLanded = false;

// Player has 3 chances
int hearts = 3;

// Game ends when hearts reach 0
boolean gameOver = false;

// Double press settings
int lastPressTime = 0;
int doublePressDelay = 400;
boolean waitingForSecondPress = false;

void setup() {
  size(800, 600);

  kitchen = loadImage("kitchen.png");
  chef = loadImage("chef_front.png");
  bread = loadImage("bread_top.png");
  breadSandwich = loadImage("bread_sandwich.png");

  // Load result and heart images
  youWin = loadImage("youWin.png");
  youLose = loadImage("youLose.png");
  heart = loadImage("heart.png");

  // Load ingredient images
  for (int i = 0; i < ingredients.length; i++) {

    fallingImages[i] = loadImage(
      ingredients[i] + "_falling.png"
    );

    sandwichImages[i] = loadImage(
      ingredients[i] + "_sandwich.png"
    );
  }

  // Connect joystick and separate button
  String[] ports = Serial.list();

  println("Available serial ports:");
  printArray(ports);

  if (ports.length > 4) {
    try {
      myPort = new Serial(this, ports[4], 9600);
      println("Connected to: " + ports[4]);
      myPort.clear();
    }
    catch (Exception e) {
      println("Serial error: " + e.getMessage());
      myPort = null;
    }
  } else {
    println("No serial port at index 4.");
  }

  // Generate random recipe
  for (int i = 0; i < recipe.length; i++) {
    int randomIndex = int(random(ingredients.length));
    recipe[i] = ingredients[randomIndex];
  }

  spawnIngredient();
}

void draw() {

  // Read joystick, button, and potentiometer
  if (myPort != null) {
    while (myPort.available() > 0) {

      String data = myPort.readStringUntil('\n');

      if (data == null) {
        break;
      }

      String[] values = split(trim(data), ',');

      if (values.length == 4) {

        int joystickX = int(values[0]);
        int button = int(values[2]);
        int potValue = int(values[3]);

        // Potentiometer controls falling speed
        fallSpeed = map(potValue, 0, 4095, 50, 1);

        if (!breadFalling && !gameOver) {

          chefX = map(
            joystickX,
            0, 4095,
            110, 690
          );

          chefX = constrain(chefX, 110, 690);
        }

        // Detect a new press of the separate button
        if (button == 0 && ButtonState == 1) {

          int currentTime = millis();

          if (waitingForSecondPress &&
              currentTime - lastPressTime <= doublePressDelay) {

            // Double press restarts the game
            waitingForSecondPress = false;
            restartGame();

          } else {

            // First press: wait for a possible second press
            lastPressTime = currentTime;
            waitingForSecondPress = true;
          }
        }

        ButtonState = button;
      }
    }
  }

  // Single press drops the top bread
  if (waitingForSecondPress &&
      millis() - lastPressTime > doublePressDelay) {

    waitingForSecondPress = false;

    if (!breadFalling && !gameOver) {

      println("SINGLE PRESS: DROP BREAD!");

      breadFalling = true;
      fallingIngredients.clear();
      bready = -fallingHeight / 2;
    }
  }

  // Draw background
  background(180, 220, 255);
  imageMode(CORNER);

  if (kitchen != null) {
    image(kitchen, 0, 0, width, height);
  }

  // Draw chef
  imageMode(CENTER);

  if (chef != null) {
    image(
      chef,
      chefX,
      height - 150,
      220,
      280
    );
  }

  // Draw recipe
  fill(255, 240, 200);
  rect(60, 30, 260, 60, 20);

  for (int i = 0; i < recipe.length; i++) {

    for (int j = 0; j < ingredients.length; j++) {

      if (recipe[i].equals(ingredients[j])) {

        if (sandwichImages[j] != null) {

          image(
            sandwichImages[j],
            100 + i * 60,
            70,
            60,
            60
          );
        }
      }
    }
  }

  // Draw remaining hearts
  imageMode(CENTER);

  for (int i = 0; i < hearts; i++) {

    if (heart != null) {
      image(
        heart,
        610 + i * 60,
        60,
        45,
        45
      );
    }
  }

  // Draw collected ingredients as a stack
  imageMode(CENTER);

  for (int i = 0; i < collected.size(); i++) {

    int index = collected.get(i);

    if (sandwichImages[index] != null) {

      image(
        sandwichImages[index],
        chefX,
        breadY - 12 - i * stackSpacing,
        sandwichWidth,
        sandwichHeight
      );
    }
  }

  // Update falling ingredients
  if (!breadFalling && !gameOver) {

    for (int i = fallingIngredients.size() - 1; i >= 0; i--) {

      FallingIngredient item = fallingIngredients.get(i);
      item.y += fallSpeed;

      // Draw falling ingredient
      if (fallingImages[item.type] != null) {

        image(
          fallingImages[item.type],
          item.x,
          item.y,
          fallingWidth,
          fallingHeight
        );
      }

      // Collision height rises as ingredients stack
      float stackY = breadY - collected.size() * stackSpacing;

      if (item.y + fallingHeight / 2 >= stackY) {

        // Wider catching area
        if (abs(item.x - chefX) <= 85) {

          // Check if ingredient is next in recipe
          int nextIndex = collected.size();

          if (nextIndex < recipe.length &&
              ingredients[item.type].equals(recipe[nextIndex])) {

            // Correct ingredient joins the stack
            collected.add(item.type);
            println("CORRECT INGREDIENT!");

          } else {

            // Wrong ingredient removes one heart
            hearts--;
            println("WRONG INGREDIENT! Hearts: " + hearts);

            if (hearts <= 0) {

              hearts = 0;
              gameOver = true;
              resultImage = youLose;
              fallingIngredients.clear();

              println("YOU LOSE!");
              break;
            }
          }
        }

        fallingIngredients.remove(i);
      }
    }
  }

  // Top bread animation
  if (breadFalling) {

    if (!breadLanded) {

      bready += 10;

      // Top bread lands on the stack
      if (bready >= 490 - collected.size() * stackSpacing) {

        bready = 490 - collected.size() * stackSpacing;
        breadLanded = true;
        checkSandwich();
      }
    }

    if (!breadLanded) {

      if (bread != null) {

        image(
          bread,
          chefX,
          bready,
          sandwichWidth,
          sandwichHeight
        );
      }

    } else {

      if (breadSandwich != null) {

        image(
          breadSandwich,
          chefX,
          bready,
          topBreadWidth,
          80
        );
      }
    }
  }

  // Spawn next ingredient
  if (millis() >= nextDropTime &&
      !breadFalling &&
      !gameOver) {

    spawnIngredient();
    nextDropTime = millis() + int(random(500, 1200));
  }

  // Show win or lose image
  if (resultImage != null) {

    imageMode(CENTER);

    image(
      resultImage,
      400,
      200,
      500,
      170
    );
  }

  imageMode(CORNER);
}

// Spawn ingredients
void spawnIngredient() {

  FallingIngredient newIngredient = new FallingIngredient();

  // 5% chance to deliberately choose the next correct ingredient
  if (collected.size() < recipe.length &&
      random(100) < 5) {

    String nextIngredient = recipe[collected.size()];

    for (int i = 0; i < ingredients.length; i++) {

      if (ingredients[i].equals(nextIngredient)) {
        newIngredient.type = i;
        break;
      }
    }

  } else {

    // Otherwise choose a random ingredient
    newIngredient.type = int(random(ingredients.length));
  }

  newIngredient.x = random(110, 690);
  newIngredient.y = -fallingHeight / 2;

  fallingIngredients.add(newIngredient);
}

// Restart the game after a double press
void restartGame() {

  println("RESTARTING GAME!");

  // Reset hearts and game state
  hearts = 3;
  gameOver = false;
  breadFalling = false;
  breadLanded = false;
  resultImage = null;

  // Reset sandwich and falling ingredients
  collected.clear();
  fallingIngredients.clear();

  // Reset top bread
  bready = 60;

  // Reset button timing
  waitingForSecondPress = false;
  lastPressTime = 0;

  // Generate a new random recipe
  for (int i = 0; i < recipe.length; i++) {
    int randomIndex = int(random(ingredients.length));
    recipe[i] = ingredients[randomIndex];
  }

  // Start spawning ingredients again
  nextDropTime = millis() + 800;
  spawnIngredient();
}

// Check completed sandwich
void checkSandwich() {

  if (collected.size() != recipe.length) {

    println("YOU LOSE!");
    resultImage = youLose;
    gameOver = true;
    return;
  }

  for (int i = 0; i < recipe.length; i++) {

    if (!recipe[i].equals(ingredients[collected.get(i)])) {

      println("YOU LOSE!");
      resultImage = youLose;
      gameOver = true;
      return;
    }
  }

  println("YOU WIN!");
  resultImage = youWin;
  gameOver = true;
}

// Class for falling ingredients
class FallingIngredient {
  int type;
  float x;
  float y;
}
