// Copyright (c) 2015-19 Electric Imp
// Copyright (c) 2021 Twilio
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

#require "Rocky.agent.lib.nut:3.0.0"

app <- Rocky.init();

/******************** User Access Control ********************/
// You should change the SALT to something unique
const SALT = "592ca97c-2996-4052-b31b-72342e348410";
function passwordHash(password, key = SALT) {
    return http.base64encode(http.hash.hmacsha512(password, SALT));
}

// default username/password is admin:admin
uac <- {
    "admin": {
        "pass": passwordHash("admin"),
        "access": ["admin", "write", "read"]
    }
};

// load user access contrl data if it exists
local savedData = server.load();
if ("uac" in savedData) uac = savedData.uac;

function saveUAC() {
    local savedData = server.load();
    if (!("uac" in savedData)) {
        savedData["uac"] <- {};
    }
    savedData.uac = uac;
    server.save(savedData);
}


// Functions for checking User Access Control
function checkAccess(user, pass, access) {
    return (user in uac && uac[user].pass == passwordHash(pass) && uac[user].access.find(access) != null);
}

function hasAdminAccess(context) {
    local user = context.auth.user;
    local pass = context.auth.pass;
    return checkAccess(user, pass, "admin");
}

function hasWriteAccess(context) {
    local user = context.auth.user;
    local pass = context.auth.pass;
    return checkAccess(user, pass, "write");
}

function hasReadAccess(context) {
    local user = context.auth.user;
    local pass = context.auth.pass;
    return checkAccess(user, pass, "read");
}

// Allow POST, PUT, PATCH, DELETE, GET, OPTIONS methods
function addMethods(context, next) {
    context.setHeader("Access-Control-Allow-Methods", "POST, PUT, PATCH, DELETE, GET, OPTIONS");
    next();
}

// Use middlewares to add PATCH and DELETE methods to app
app.use([ addMethods ]);

// Create a new user (no authorize function since anyone can create a user)
app.post("/users", function(context) {
    // make sure required parameters are there
    if(!("user" in context.req.body && "pass" in context.req.body)) {
        context.send(406, "Not Acceptable - Missing parameter(s) - user, pass");
        return;
    }

    local user = context.req.body.user;
    local pass = context.req.body.pass;

    // make sure username is unique
    if (user in uac) {
        context.send(406, "Duplicate Username - please enter a new username");
        return;
    }

    uac[user] <- {
        "pass": passwordHash(pass),
        "access": ["read"]
    };
    saveUAC();


    // respond back with the user object (no password)
    context.send({ "username": user , "access": uac[user].access });
});

// Delete a user
app.on("DELETE", "/users/([^/]*)", function(context) {
    // grab the username from the regex
    local username = context.matches[1];

    // if the user doesn't exist:
    if (!(username in uac)) {
        context.send(406, "Unknown user: " + username);
        return;
    }

    // if it does exist, delete it, then return 200, OK
    delete uac[username];
    context.send("OK");
}).authorize(hasAdminAccess);

// Edit a user's settings
app.on("PATCH", "/users/([^/]*)", function(context) {
    // grab the username
    local username = context.matches[1];

    // if the user does exist
    if (!(username in uac)) {
        context.send(406, "Unknown user: " + username);
        return;
    }

    // if an access array was passed, assign it
    if ("access" in context.req.body) {
        local access = context.req.body.access;
        if (!(typeof(access) == "array")) {
            context.send(406, "Bad parameter \'access\' - Expected json array, received " + typeof(access));
            return;
        }
        uac[username].access = access;
    }

    // if a new password was sent, hash it and store it
    if ("pass" in context.req.body) {
        local hashedPassword = hashPassword(context.req.body.pass);
        uac[username].pass = hashedPassword;
    }

    // save the uac table
    saveUAC();

    context.send({ "user": username, "access": uac[username].access });
    return;
}).authorize(hasAdminAccess);


/******************** Application Code ********************/
led <- {
    color = { red = "UNKNOWN", green = "UNKNOWN", blue = "UNKNOWN" },
    state = "UNKNOWN"
};

device.on("info", function(data) {
    led = data;
});

app.get("/color", function(context) {
    context.send(200, { color = led.color });
}).authorize(hasReadAccess);

app.get("/state", function(context) {
    context.send({ state = led.state });
}).authorize(hasReadAccess);

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
}).authorize(hasWriteAccess);

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
}).authorize(hasWriteAccess);
