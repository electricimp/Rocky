// Copyright (c) 2015-19 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

redPin <- hardware.pin1;
greenPin <- hardware.pin2;
bluePin <- hardware.pin5;

redPin.configure(PWM_OUT, 1.0/400.0, 0.0);
greenPin.configure(PWM_OUT, 1.0/400.0, 0.0);
bluePin.configure(PWM_OUT, 1.0/400.0, 0.0);

red <- 0;   // 0 - 255
green <- 0; // 0 - 255
blue <- 0;  // 0 - 255

state <- 0; // 0 = off, 1 = on

function sendInfo(nullData = null) {
    agent.send("info", {
        color = [red, green, blue],
        state = state
    });
}

function setColor(colors) {
    foreach(i, color in colors) {
        color = color.tointeger();
        if (color < 0) colors[i] = 0;
        if (color > 255) colors[i] = 255;
    }

    red = colors.red;
    green = colors.green;
    blue = colors.blue;

    update();
}

function setState(s) {
    s = s.tointeger();
    if (s == 0) state = 0;
    else state = 1;

    update();
}

function update() {
    if (state == 0) {
        redPin.write(0);
        greenPin.write(0);
        bluePin.write(0);
    } else {
        redPin.write(red/255.0);
        greenPin.write(green/255.0);
        bluePin.write(blue/255.0);
    }
}

agent.on("setColor", setColor);
agent.on("setState", setState);
agent.on("getInfo", sendInfo);

sendInfo();
