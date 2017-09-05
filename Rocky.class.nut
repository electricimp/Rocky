// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class Rocky {

    static VERSION = "2.0.0";

    static PARSE_ERROR = "Error parsing body of request";
    static INVALID_MIDDLEWARE_ERR = "Middleware must be a function, or array of functions";
    static INVALID_TIMEOUT_ERR = "Timeout must be a number";
    static INVALID_ALLOW_UNSECURE_ERR = "allowUnsecure must be a boolean";
    static INVALID_STRICT_ROUTING_ERR = "strictRouting must be a boolean";
    static INVALID_ACCESS_CONTROL_ERR = "accessControl must be a boolean";
    static INVALID_VERB_ERR = "Verb must be a string";
    static INVALID_SIGNATURE_ERR = "Signature must be a string";
    static INVALID_CALLBACK_ERR = "Callback must be a string";
    static ERROR_MISSING_NAME = "'name' is required for each file in multipart/form-data packet";
    static ERROR_MISSING_BODY = "Body is required for each file in multipart/form-data packet (must be preceded by an empty line)";
    static ERROR_MISSING_TYPE = "Content-Type is required for each file in multipart/form-data packet";

    // Route handlers, event handers, and middleware
    _handlers = null;

    // Settings:
    _timeout = 10;
    _strictRouting = false;
    _allowUnsecure = false;
    _accessControl = true;

    constructor(settings = {}) {
        // Initialize settings
        if ("timeout" in settings) {
            if (["integer", "float"].find(typeof settings.timeout) == null) {
                throw INVALID_TIMEOUT_ERR;
            }
            _timeout = settings.timeout;
        }
        if ("allowUnsecure" in settings) {
            if (!(typeof settings.allowUnsecure == "bool")) {
                throw INVALID_ALLOW_UNSECURE_ERR;
            }
            _allowUnsecure = settings.allowUnsecure;
        }
        if ("strictRouting" in settings) {
            if (!(typeof settings.strictRouting == "bool")) {
                throw INVALID_STRICT_ROUTING_ERR;
            }
            _strictRouting = settings.strictRouting;
        }
        if ("accessControl" in settings) {
            if (!(typeof settings.accessControl == "bool")) {
                throw INVALID_ACCESS_CONTROL_ERR;
            }
            _accessControl = settings.accessControl;
        }

        // Inititalize handlers & middleware
        _handlers = {
            authorize = _defaultAuthorizeHandler.bindenv(this),
            onUnauthorized = _defaultUnauthorizedHandler.bindenv(this),
            onTimeout = _defaultTimeoutHandler.bindenv(this),
            onNotFound = _defaultNotFoundHandler.bindenv(this),
            onException = _defaultExceptionHandler.bindenv(this),
            middlewares = []
        };

        // Bind the onrequest handler
        http.onrequest(_onrequest.bindenv(this));
    }

    //-------------------- STATIC METHODS --------------------//
    static function getContext(id) {
        return Rocky.Context.get(id);
    }

    static function sendToAll(statuscode, response, headers = {}) {
        Rocky.Context.sendToAll(statuscode, response, headers);
    }

    //-------------------- PUBLIC METHODS --------------------//

    // Requests
    function on(verb, signature, callback, timeout=null) {
        //Check timeout and set it to class-level timeout if not specified for route
        if (timeout == null) {
            timeout = this._timeout;
        }

        // Validate paramters
        if (!(typeof verb == "string")) {
            throw INVALID_VERB_ERR;
        }
        if (!(typeof signature == "string")) {
            throw INVALID_SIGNATURE_ERR;
        }
        if (!(typeof callback == "function")) {
            throw INVALID_CALLBACK_ERR;
        }
        if (["integer", "float"].find(typeof timeout) == null) {
            throw INVALID_TIMEOUT_ERR;
        }

        // Register this signature and verb against the callback
        verb = verb.toupper();

        signature = signature.tolower();
        if (!(signature in _handlers)) _handlers[signature] <- {};

        local routeHandler = Rocky.Route(callback);
        routeHandler.setTimeout(timeout);

        _handlers[signature][verb] <- routeHandler;

        return routeHandler;
    }

    function post(signature, callback, timeout=null) {
        return on("POST", signature, callback, timeout);
    }

    function get(signature, callback, timeout=null) {
        return on("GET", signature, callback, timeout);
    }

    function put(signature, callback, timeout=null) {
        return on("PUT", signature, callback, timeout);
    }

    // Authorization
    function authorize(callback) {
        _handlers.authorize <- callback;
        return this;
    }

    function onUnauthorized(callback) {
        _handlers.onUnauthorized <- callback;
        return this;
    }

    // Events
    function onTimeout(callback, t = null) {
        if (t == null) t = _timeout;

        _handlers.onTimeout <- callback;
        _timeout = t;
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

    // Middlewares
    function use(middlewares) {
        if(typeof middlewares == "function") {
            _handlers.middlewares.push(middlewares);
        } else if (typeof _handlers.middlewares == "array") {
            foreach(middleware in middlewares) {
                use(middleware);
            }
        } else {
            throw INVALID_MIDDLEWARE_ERR;
        }

        return this;
    }

    //-------------------- PRIVATE METHODS --------------------//
    // Adds default access control headers
    function _addAccessControl(res) {
        res.header("Access-Control-Allow-Origin", "*")
        res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
        res.header("Access-Control-Allow-Methods", "POST, PUT, GET, OPTIONS");
    }

    // The HTTP Request Handler
    function _onrequest(req, res) {
        // Add access control headers if required
        if (_accessControl) _addAccessControl(res);

        // Setup the context for the callbacks
        local context = Rocky.Context(req, res);

        // Check for unsecure reqeusts
        if (_allowUnsecure == false && "x-forwarded-proto" in req.headers && req.headers["x-forwarded-proto"] != "https") {
            context.send(405, "HTTP not allowed.");
            return;
        }

        // Parse the request body back into the body
        try {
            req.rawbody <- req.body;
            req.body = _parse_body(req);
        } catch (err) {
            context.send(400, Rocky.PARSE_ERROR);
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
            local timeout = route.handler.getTimeout();

            if (route.handler.hasHandler("onTimeout")) {
                onTimeout = route.handler.getHandler("onTimeout");
            }

            context.setTimeout(timeout, onTimeout);
            route.handler.execute(context, _handlers);
        } else {
            // if we don't have a handler
            _handlers.onNotFound(context);
        }
    }

    function _parse_body(req) {
        local contentType = "content-type" in req.headers ? req.headers["content-type"] : "";

        if (contentType == "application/json" || contentType.find("application/json;") != null) {
            if (req.body == "" || req.body == null) return null;
            return http.jsondecode(req.body);
        }

        if (contentType == "application/x-www-form-urlencoded" || contentType.find("application/x-www-form-urlencoded;") != null) {
            if (req.body == "" || req.body == null) return null;
            return http.urldecode(req.body);
        }

        if (contentType.find("multipart/form-data;") == 0) {
            local parts = [];

            // Find the boundary in the contentType
            local boundary;
            local findString = regexp(@"boundary([ ]*)=");
            local match = findString.search(contentType);

            if (match) {
                boundary = contentType.slice(match.end);
                boundary = strip(boundary);
            } else {
                throw "No boundary found in content-type";
            }

            // Remove all carriage returns from string (to support either \r\n or \n for linebreaks)
            local body = "";
            local bodyLines = split(req.body, "\r");
            foreach (i, line in bodyLines) {
                body += line;
            }

            local bindex = -1;
            do {
                try {
                bindex = body.find("--" + boundary + "\n", bindex+1);

                if (bindex != null) {
                    // Locate all the parts
                    local hstart = bindex + boundary.len() + 3;
                    local hfinish = body.find("\n\n", hstart);
                    local header = body.slice(hstart, hfinish);
                    /*
                    local hstart = body.find("Content-Disposition:", bindex + boundary.len()) + 20;
                    local hfinish = body.find("\n", hstart);
                    local header = body.slice(hstart, hfinish);
                    */

                    // Get the name
                    local name = null;
                    local nstart = header.find(" name=\"");
                    if (nstart != null) {
                        nstart += 7;
                        local nfinish = header.find("\"", nstart);
                        name = header.slice(nstart, nfinish);
                    } else {
                        throw ERROR_MISSING_NAME;
                    }

                    // Get the filename
                    local filename = null;
                    local fnstart = header.find(" filename=\"");
                    if (fnstart != null) {
                        fnstart += 11;
                        local fnfinish = header.find("\"", fnstart);
                        filename = header.slice(fnstart, fnfinish);
                    }

                    // Get the Content-Type
                    local type = null;
                    local tstart = header.find("Content-Type:");
                    if (tstart != null) {
                        tstart += 13;
                        local tfinish = header.find("\n", tstart);
                        if (tfinish == null) tfinish = header.len();
                        type = strip(header.slice(tstart, tfinish));
                    } else {
                        throw ERROR_MISSING_TYPE;
                    }

                    // Get the body
                    local data = null;
                    local bstart = body.find("\n\n", hstart);
                    if (bstart != null) {
                        bstart += 2;
                        local bfinish = body.find("\n--" + boundary, bstart);
                        data = body.slice(bstart, bfinish);
                    } else {
                        throw ERROR_MISSING_BODY;
                    }

                    local part = { "name": name, "data": data, "content-type": type };
                    if (filename != null) part.filename <- filename;

                    parts.push(part);
                }
                } catch (e) {
                    server.error(e);
                    throw e;
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

    //-------------------- DEFAULT HANDLERS --------------------//
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
        server.error(ex);
        context.send(500, "Agent Error: " + ex);
    }

}

class Rocky.Route {
    _handlers = null;
    _timeout = null;
    _callback = null;

    constructor(callback) {
        _handlers = {
            middlewares = []
        };
        _timeout = 10;
        _callback = callback;
    }

    //-------------------- PUBLIC METHODS --------------------//
    function execute(context, defaultHandlers) {
        // setup handlers
        // NOTE: Copying these handlers into the route might have some unintended side effect.
        //       Consider changing this if issues come up.
        foreach (handlerName, handler in defaultHandlers) {
            // Copy over the non-middleware handlers
            if (handlerName != "middlewares") {
                if (!hasHandler(handlerName)) { _setHandler(handlerName, handler); }
            } else {
                // Copy the handlers over so we can iterate through in
                // the correct order:
                for (local i = handler.len() -1; i >= 0; i--) {
                    // Only add handlers that we haven't already added
                    if (_handlers.middlewares.find(handler[i]) == null) {
                        _handlers.middlewares.insert(0, handler[i]);
                    }
                }
            }
        }

        // Run all the handlers
        _invokeNextHandler(context);
    }

    function authorize(callback) {
        return _setHandler("authorize", callback);
    }

    function onException(callback) {
        return _setHandler("onException", callback);
    }

    function onUnauthorized(callback) {
        return _setHandler("onUnauthorized", callback);
    }

    function onTimeout(callback, t = null) {
        if (t == null) t = _timeout;
        _timeout = t;

        return _setHandler("onTimeout", callback);
    }

    function use(middlewares) {
        if (!hasHandler("middlewares")) { _handlers["middlewares"] <- [] };

        if(typeof middlewares == "function") {
            _handlers.middlewares.push(middlewares);
        } else if (typeof _handlers.middlewares == "array") {
            foreach(middleware in middlewares) {
                use(middleware);
            }
        } else {
            throw INVALID_MIDDLEWARE_ERR;
        }

        return this;
    }

    function hasHandler(handlerName) {
        return (handlerName in _handlers);
    }

    function getHandler(handlerName) {
        // Return null if no handler
        if (!hasHandler(handlerName)) { return null; }

        // Return the handler if it exists
        return _handlers[handlerName];
    }

    function getTimeout() {
        return _timeout;
    }

    function setTimeout(timeout) {
        return _timeout = timeout;
    }

    //-------------------- PRIVATE METHODS --------------------//

    // Invokes the next middleware, and moves on the
    // authorize/callback/onUnauthorized flow when done with middlewares
    function _invokeNextHandler(context, idx = 0) {
        // If we've sent a response, we're done
        if (context.isComplete()) return;

        // check if we have middlewares left to execute
        if (idx < _handlers.middlewares.len()) {
            try {
                // if we do, execute them (with a next() function for the next middleware)
                _handlers.middlewares[idx](context, _nextGenerator(context, idx+1));
            } catch (ex) {
                _handlers.onException(context, ex);
            }
        } else {
            // Otherwise, run the rest of the flow
            try {
                // Check if we're authorized
                if (_handlers.authorize(context)) {
                    // If we're authorized, execute the route handler
                    _callback(context);
                } else {
                    // if we unauthorized, execute the onUnauthorized handler
                    _handlers.onUnauthorized(context);
                }
            } catch (ex) {
                _handlers.onException(context, ex);
            }
        }
    }

    // Generator method to create next() functions for middleware
    function _nextGenerator(context, idx) {
        return function() { _invokeNextHandler(context, idx); }.bindenv(this);
    }


    // Sets a handlers (used internally to simplify code)
    function _setHandler(handlerName, callback) {
        // Create handler slot if required
        if (!hasHandler(handlerName)) { _handlers[handlerName] <- null; }

        // Set the handler
        _handlers[handlerName] = callback;

        return this;
    }
}

class Rocky.Context {
    req = null;
    res = null;
    sent = null;
    id = null;
    time = null;
    auth = null;
    path = null;
    matches = null;
    timer = null;
    userdata = null;
    static _contexts = {};

    constructor(_req, _res) {
        req = _req;
        res = _res;
        sent = false;
        time = date();
        userdata = {};

        // Identify and store the context
        do {
            id = math.rand();
        } while (id in _contexts);
        _contexts[id] <- this;
    }

    //-------------------- STATIC METHODS --------------------//
    static function get(id) {
        if (id in _contexts) {
            return _contexts[id];
        } else {
            return null;
        }
    }

    // Closes ALL contexts
    static function sendToAll(statuscode, response, headers = {}) {
        local contextsArray = [];

        // Convert table into array because when contexts are removed
        // from the table while looping through it, it causes issues
        foreach (key, context in _contexts) {
            contextsArray.push(context);
        }

        // Loop over array and send to all active contexts
        for (local i = contextsArray.len() - 1; i >= 0; i--) {
            foreach (key, value in headers) {
                contextsArray[i].setHeader(key, value);
            }
            contextsArray[i].send(statuscode, response);
        }
    }

    //-------------------- PUBLIC METHODS --------------------//
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

    function send(code, message = null, forcejson = false) {
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

        if (forcejson) {
            // Encode whatever it is as a json object
            res.header("Content-Type", "application/json; charset=utf-8");
            res.send(code, http.jsonencode(message));
        } else if (message == null && typeof code == "integer") {
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

    function isComplete() {
        return sent;
    }
}
