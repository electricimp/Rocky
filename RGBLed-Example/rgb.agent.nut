// Copyright (c) 2015-19 Electric Imp
// Copyright (c) 2020-23 KORE Wireless
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

#require "Rocky.agent.lib.nut:3.0.0"

/******************** Application Code ********************/
led <- {
    color = { red = "UNKNOWN", green = "UNKNOWN", blue = "UNKNOWN" },
    state = "UNKNOWN"
};

device.on("info", function(data) {
    led = data;
});

app <- Rocky.init();

app.get("/color", function(context) {
    context.send(200, { color = led.color });
});
app.get("/state", function(context) {
    context.send({ state = led.state });
});
app.post("/color", function(context) {
    try {
        // Preflight check
        if (!("color" in context.req.body)) throw "Missing param: color";
        if (!("red" in context.req.body.color)) throw "Missing param: color.red";
        if (!("green" in context.req.body.color)) throw "Missing param: color.green";
        if (!("blue" in context.req.body.color)) throw "Missing param: color.blue";

        // if preflight check passed - do things
        led.color = context.req.body.color;
        server.log("Setting color to R: " + led.color.red + ", G: " + led.color.green + ", B: " + led.color.blue);
        device.send("setColor", led.color);

        // send the response
        context.send({ "verb": "POST", "led": led });
    } catch (ex) {
        context.send(400, ex);
        return;
    }
});

app.post("/state", function(context) {
    try {
        // Preflight check
        if (!("state" in context.req.body)) throw "Missing param: state";
    } catch (ex) {
        context.send(400, ex);
        return;
    }

    // if preflight check passed - do things
    led.state = context.req.body.state;
    server.log("Setting state to " + (led.state ? "on" : "off"));
    device.send("setState", led.state);

    // send the response
    context.send({ "verb": "POST", "led": led });
});
