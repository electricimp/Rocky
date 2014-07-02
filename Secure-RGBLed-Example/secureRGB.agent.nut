class Rocky {
    _handlers = null;
    
    // Settings:
    _timeout = 10;
    _strictRouting = false;
    _allowUnsecure = false;
    
    constructor(settings = {}) {
        if ("timeout" in settings) _timeout = settings.timeout;
        if ("allowUnsecure" in settings) _allowUnsecure = settings.allowUnsecure;
        if ("strictRouting" in settings) _strictRouting = settings.strictRouting;

        _handlers = { 
            authorize = _defaultAuthorizeHandler.bindenv(this),
            onUnauthorized = _defaultUnauthorizedHandler.bindenv(this),
            onTimeout = _defaultTimeoutHandler.bindenv(this), 
            onNotFound = _defaultNotFoundHandler.bindenv(this),
            onException = _defaultExceptionHandler.bindenv(this),
        };
        
        http.onrequest(_onrequest.bindenv(this));
    }
    
    /************************** [ PUBLIC FUNCTIONS ] **************************/
    function on(verb, signature, callback) {
        // Register this signature and verb against the callback
        verb = verb.toupper();
        signature = signature.tolower();
        if (!(signature in _handlers)) _handlers[signature] <- {};
        
        local routeHandler = Rocky.Route(callback);
        _handlers[signature][verb] <- routeHandler;

        return routeHandler;
    }
    
    function post(signature, callback) {
        return on("POST", signature, callback);
    }
    
    function get(signature, callback) {
        return on("GET", signature, callback);
    }
    
    function put(signature, callback) {
        return on("PUT", signature, callback);
    }
    
    function authorize(callback) {
        _handlers.authorize <- callback;
        return this;
    }
    
    function onUnauthorized(callback) {
        _handlers.onUnauthorized <- callback;
        return this;
    }
    
    function onTimeout(callback, timeout = 10) {
        _handlers.onTimeout <- callback;
        _timeout = timeout;
        return this;
    }
    
    function onNotFound(callback) {
        _handlers.onNotFound <- callback;
        return this;
    }
    
    function onException(callback) {
        _handlers.onException <- callback;
        return this;
    }

    // This should come from the context bind not the class
    function access_control() {
        // We should probably put this as a default OPTION handler, but for now this will do
        // It is probably never required tho as this is an API handler not a HTML handler
        res.header("Access-Control-Allow-Origin", "*")
        res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    }
    
    /************************** [ PRIVATE FUNCTIONS ] *************************/
    function _onrequest(req, res) {
        // Setup the context for the callbacks
        local context = Rocky.Context(req, res);
        
        // Check for unsecure reqeusts
        if (_allowUnsecure == false && "x-forwarded-proto" in req.headers && req.headers["x-forwarded-proto"] != "https") {
            context.send(405, "HTTP not allowed.");
            return;
        }
        
        // Parse the request body back into the body
        try {
            req.body = _parse_body(req);
        } catch (e) {
            server.log("Parse error '" + e + "' when parsing:\r\n" + req.body)
            context.send(400, e);
            return;
        }

        // Look for a handler for this path
        local route = _handler_match(req);
        if (route) {
            // if we have a handler
            context.path = route.path;
            context.matches = route.matches;
            
            // parse auth
            context.auth = _parse_authorization(context);
            
            // Create timeout
            local onTimeout = _handlers.onTimeout;
            local timeout = _timeout;
            
            if (route.handler.hasTimeout()) {
                onTimeout = route.handler.onTimeout; 
                timeout = route.handler.timeout;
            }
            
            context.setTimeout(_timeout, onTimeout);
            route.handler.execute(context, _handlers);
        } else {
            // if we don't have a handler
            _handlers.onNotFound(context);
        }
    }

    function _parse_body(req) {
        if ("content-type" in req.headers && req.headers["content-type"] == "application/json") {
            if (req.body == "" || req.body == null) return null;
            return http.jsondecode(req.body);
        }
        if ("content-type" in req.headers && req.headers["content-type"] == "application/x-www-form-urlencoded") {
            return http.urldecode(req.body);
        }
        if ("content-type" in req.headers && req.headers["content-type"].slice(0,20) == "multipart/form-data;") {
            local parts = [];
            local boundary = req.headers["content-type"].slice(30);
            local bindex = -1;
            do {
                bindex = req.body.find("--" + boundary + "\r\n", bindex+1);
                if (bindex != null) {
                    // Locate all the parts
                    local hstart = bindex + boundary.len() + 4;
                    local nstart = req.body.find("name=\"", hstart) + 6;
                    local nfinish = req.body.find("\"", nstart);
                    local fnstart = req.body.find("filename=\"", hstart) + 10;
                    local fnfinish = req.body.find("\"", fnstart);
                    local bstart = req.body.find("\r\n\r\n", hstart) + 4;
                    local fstart = req.body.find("\r\n--" + boundary, bstart);
                    
                    // Pull out the parts as strings
                    local headers = req.body.slice(hstart, bstart);
                    local name = null;
                    local filename = null;
                    local type = null;
                    foreach (header in split(headers, ";\n")) {
                        local kv = split(header, ":=");
                        if (kv.len() == 2) {
                            switch (strip(kv[0]).tolower()) {
                                case "name":
                                    name = strip(kv[1]).slice(1, -1);
                                    break;
                                case "filename":
                                    filename = strip(kv[1]).slice(1, -1);
                                    break;
                                case "content-type":
                                    type = strip(kv[1]);
                                    break;
                            }
                        }
                    }
                    local data = req.body.slice(bstart, fstart);
                    local part = { "name": name, "filename": filename, "data": data, "content-type": type };

                    parts.push(part);
                }
            } while (bindex != null);
            
            return parts;
        }
        
        // Nothing matched, send back the original body
        return req.body;
    }

    function _parse_authorization(context) {
        if ("authorization" in context.req.headers) {
            local auth = split(context.req.headers.authorization, " ");
            
            if (auth.len() == 2 && auth[0] == "Basic") {
                // Note the username and password can't have colons in them
                local creds = http.base64decode(auth[1]).tostring();
                creds = split(creds, ":"); 
                if (creds.len() == 2) {
                    return { authType = "Basic", user = creds[0], pass = creds[1] };
                }
            } else if (auth.len() == 2 && auth[0] == "Bearer") {
                // The bearer is just the password
                if (auth[1].len() > 0) {
                    return { authType = "Bearer", user = auth[1], pass = auth[1] };
                }
            }
        }
        
        return { authType = "None", user = "", pass = "" };
    }
    
    function _extract_parts(routeHandler, path, regexp = null) {
        local parts = { path = [], matches = [], handler = routeHandler };
        
        // Split the path into parts
        foreach (part in split(path, "/")) {
            parts.path.push(part);
        }
        
        // Capture regular expression matches
        if (regexp != null) {
            local caps = regexp.capture(path);
            local matches = [];
            foreach (cap in caps) {
                parts.matches.push(path.slice(cap.begin, cap.end));
            }
        }
        
        return parts;
    }
    
    function _handler_match(req) {
        local signature = req.path.tolower();
        local verb = req.method.toupper();

        // ignore trailing /s if _strictRouting == false
        if(!_strictRouting) {
            while (signature.len() > 1 && signature[signature.len()-1] == '/') {
                signature = signature.slice(0, signature.len()-1);
            }
        }

        if ((signature in _handlers) && (verb in _handlers[signature])) {
            // We have an exact signature match
            return _extract_parts(_handlers[signature][verb], signature);
        } else if ((signature in _handlers) && ("*" in _handlers[signature])) {
            // We have a partial signature match
            return _extract_parts(_handlers[signature]["*"], signature);
        } else {
            // Let's iterate through all handlers and search for a regular expression match
            foreach (_signature,_handler in _handlers) {
                if (typeof _handler == "table") {
                    foreach (_verb,_callback in _handler) {
                        if (_verb == verb || _verb == "*") {
                            try {
                                local ex = regexp(_signature);
                                if (ex.match(signature)) {
                                    // We have a regexp handler match
                                    return _extract_parts(_callback, signature, ex);
                                }
                            } catch (e) {
                                // Don't care about invalid regexp.
                            }
                        }
                    }
                }
            }
        }
        return null;
    }
    
    /*************************** [ DEFAULT HANDLERS ] *************************/
    function _defaultAuthorizeHandler(context) {
        return true;
    }
    
    function _defaultUnauthorizedHandler(context) {
        context.send(401, "Unauthorized");
    }
    
    function _defaultNotFoundHandler(context) {
        context.send(404, format("No handler for %s %s", context.req.method, context.req.path));
    }
    
    function _defaultTimeoutHandler(context) {
        context.send(500, format("Agent Request Timedout after %i seconds.", _timeout));
    }
    
    function _defaultExceptionHandler(context, ex) {
        context.send(500, "Agent Error: " + ex);
    }
}

class Rocky.Route {
    handlers = null;
    timeout = null;
    
    _callback = null;
    
    constructor(callback) {
        handlers = {};
        timeout = 10;
        
        _callback = callback;
    }
    
    /************************** [ PUBLIC FUNCTIONS ] **************************/
    function execute(context, defaultHandlers) {
        try {
            // setup handlers
            foreach (handlerName, handler in defaultHandlers) {
                if (!(handlerName in handlers)) handlers[handlerName] <- handler;
            }

            if(handlers.authorize(context)) {
                _callback(context);
            }
            else {
                handlers.onUnauthorized(context);
            }
        } catch(ex) {
            handlers.onException(context, ex);
        }
    }
    
    function authorize(callback) {
        handlers.authorize <- callback;
        return this;
    }
    
    function onException(callback) {
        handlers.onException <- callback;
        return this;
    }
    
    function onUnauthorized(callback) {
        handlers.onUnauthorized <- callback;
        return this;        
    }
    
    function onTimeout(callback, t = 10) {
        handlers.onTimeout <- callback;
        timeout = t;
        return this;
    }
    
    function hasTimeout() {
        return ("onTimeout" in handlers);
    }
}

class Rocky.Context {
    req = null;
    res = null;
    sent = false;
    id = null;
    time = null;
    auth = null;
    path = null;
    matches = null;
    timer = null;
    static _contexts = {};

    constructor(_req, _res) {
        req = _req;
        res = _res;
        sent = false;
        time = date();
        
        // Identify and store the context
        do {
            id = math.rand();
        } while (id in _contexts);
        _contexts[id] <- this;
    }
    
    /************************** [ PUBLIC FUNCTIONS ] **************************/
    function get(id) {
        if (id in _contexts) {
            return _contexts[id];
        } else {
            return null;
        }
    }
    
    function isbrowser() {
        return (("accept" in req.headers) && (req.headers.accept.find("text/html") != null));
    }
    
    function getHeader(key, def = null) {
        key = key.tolower();
        if (key in req.headers) return req.headers[key];
        else return def;
    }
    
    function setHeader(key, value) {
        return res.header(key, value);
    }
    
    function send(code, message = null) {
        // Cancel the timeout
        if (timer) {
            imp.cancelwakeup(timer);
            timer = null;
        }
        
        // Remove the context from the store
        if (id in _contexts) {
            delete Rocky.Context._contexts[id];
        }

        // Has this context been closed already?
        if (sent) {
            return false;
        } 
        
        if (message == null && typeof code == "integer") {
            // Empty result code
            res.send(code, "");
        } else if (message == null && typeof code == "string") {
            // No result code, assume 200
            res.send(200, code);
        } else if (message == null && (typeof code == "table" || typeof code == "array")) {
            // No result code, assume 200 ... and encode a json object
            res.header("Content-Type", "application/json; charset=utf-8");
            res.send(200, http.jsonencode(code));
        } else if (typeof code == "integer" && (typeof message == "table" || typeof message == "array")) {
            // Encode a json object
            res.header("Content-Type", "application/json; charset=utf-8");
            res.send(code, http.jsonencode(message));
        } else {
            // Normal result
            res.send(code, message);
        }
        sent = true;
    }
    
    function setTimeout(timeout, callback) {
        // Set the timeout timer
        if (timer) imp.cancelwakeup(timer);
        timer = imp.wakeup(timeout, function() {
            if (callback == null) {
                send(502, "Timeout");
            } else {
                callback(this);
            }
        }.bindenv(this))
    }
}

app <- Rocky();

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
function checkAccess(user,pass, access) {
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
app.on("delete", "/users/([^/]*)", function(context) {
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
app.request("PATCH", "/users/([^/]*)", function(context) {
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
        setColor(context.req.body.color);
        context.send({ verb = "POST", color = led.color });
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
    setState(context.req.body.state);
    context.send({ verb = "POST", state = led.state });
}).authorize(hasWriteAccess);

