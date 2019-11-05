enum ROCKY_ERROR {
    PARSE = "Error parsing body of request",
    MIDDLEWARE = "Invalid middleware",
    TIMEOUT = "Bad timeout value - must be an integer or float",
    NO_BOUNDARY = "No boundary found in content-type"
}

const ROCKY_PARSE_ERROR =

/**
 * This class allows you to define and operate an agent-served API.
 *
 * @copyright Electric Imp, Inc. 2015-19
 * @license   MIT
 *
 * @class
 *
*/
class Rocky {

    static VERSION = "3.0.0";

    // ------------------ PRIVATE PROPERTIES ------------------//

    // Route handlers, event handers and middleware
    // are all stored in the same array
    _handlers = null;

    // Settings
    _timeout = 10;
    _strictRouting = false;
    _allowUnsecure = false;
    _accessControl = true;

    /**
     * The Rocky constructor.
     *
     * @constructor
     *
     * @param {table} settings - Optional instance behavior settings. Default: see values above.
     *
     * @returns {object} A Rocky instance.
     *
    */
    constructor(settings = {}) {
        // ADDED 3.0.0
        // If this is the first instance, record its reference as a global
        if (!("rocky_singleton_control" in getroottable())) {
            ::rocky_singleton_control <- this;
        }

        // Initialize settings
        if ("timeout" in settings) _timeout = settings.timeout;
        if ("allowUnsecure" in settings) _allowUnsecure = settings.allowUnsecure;
        if ("strictRouting" in settings) _strictRouting = settings.strictRouting;
        if ("accessControl" in settings) _accessControl = settings.accessControl;

        // Inititalize handlers and middleware
        _handlers = {
            authorize = _defaultAuthorizeHandler.bindenv(this),
            onUnauthorized = _defaultUnauthorizedHandler.bindenv(this),
            onTimeout = _defaultTimeoutHandler.bindenv(this),
            onNotFound = _defaultNotFoundHandler.bindenv(this),
            onException = _defaultExceptionHandler.bindenv(this),
            middlewares = []
        };

        // Bind the instance's onrequest handler
        http.onrequest(_onrequest.bindenv(this));
    }

    //-------------------- STATIC METHODS --------------------//

    /**
     * Create or return the Rocky singleton.
     *
     * @param {table} settings - Optional instance behavior settings. Default: see constructor.
     *
     * @returns {object} The Rocky singleton instance.
     *
    */
    static function init(options = null) {
        // FROM 3.0.0
        if ("rocky_singleton_control" in getroottable()) {
            // Return a reference to the first Rocky singleton if present...
            return ::rocky_singleton_control;
        } else {
            // ...or create a new instance (which will become the singleton)
            return Rocky(options);
        }
    }

    /**
     * Get the specified Rocky context.
     *
     * @param {integer} id - The identifier of the desired context.
     *
     * @returns {object} The requested Rocky.Context instance.
    */
    static function getContext(id) {
        return Rocky.Context.get(id);
    }

    /**
     * Send a response to to all currently active requests.
     *
     * @param {integer} statuscode - The response's HTTP status code.
     * @param {any}     response   - The response body.
     * @param {table}   headers    - Optional additional response headers. Default: no additional headers.
     *
    */
    static function sendToAll(statuscode, response, headers = {}) {
        Rocky.Context.sendToAll(statuscode, response, headers);
    }

    //-------------------- PUBLIC METHODS --------------------//

    // -------------------    REQUESTS    --------------------//

    /**
     * Register a handler for a non-standard (GET, PUT or POST) HTTP request.
     *
     * @param {string}   verb      - The HTTP request verb.
     * @param {string}   signature - An endpoint path signature.
     * @param {function} callback  - The handler that will process this kind of request.
     * @param {integer}  timeout   - Optional timeout period in seconds. Default: the class-level value.
     *
     * @returns {object} A Rocky.Route instance for the handler.
    */
    function on(verb, signature, callback, timeout = null) {
        // Check timeout and set it to class-level timeout if not specified for route
        if (timeout == null) timeout = this._timeout;
        // ADDED 3.0.0 -- enforce timeout type (fix for https://github.com/electricimp/Rocky/issues/23)
        if (typeof timeout != "integer" && typeof timeout != "float") throw ROCKY_ERROR.TIMEOUT;

        // Register this verb and signature against the callback
        verb = verb.toupper();
        signature = signature.tolower();
        if (!(signature in _handlers)) _handlers[signature] <- {};

        local routeHandler = Rocky.Route(callback);
        routeHandler.setTimeout(timeout);
        _handlers[signature][verb] <- routeHandler;
        return routeHandler;
    }

    /**
     * Register a handler for an HTTP POST request.
     *
     * @param {string}   signature - An endpoint path signature.
     * @param {function} callback  - The handler that will process the POST request.
     * @param {integer}  timeout   - Optional timeout in seconds. Default: the class-level value.
     *
     * @returns {object} A Rocky.Route instance for the handler.
    */
    function post(signature, callback, timeout=null) {
        return on("POST", signature, callback, timeout);
    }

    /**
     * Register a handler for an HTTP GET request.
     *
     * @param {string}   signature - An endpoint path signature.
     * @param {function} callback  - The handler that will process the GET request.
     * @param {integer}  timeout   - Optional timeout in seconds. Default: the class-level value.
     *
     * @returns {object} A Rocky.Route instance for the handler.
    */
    function get(signature, callback, timeout=null) {
        return on("GET", signature, callback, timeout);
    }

    /**
     * Register a handler for an HTTP PUT request.
     *
     * @param {string}   signature - An endpoint path signature.
     * @param {function} callback  - The handler that will process the PUT request.
     * @param {integer}  timeout   - Optional timeout in seconds. Default: the class-level value.
     *
     * @returns {object} A Rocky.Route instance for the handler.
    */
    function put(signature, callback, timeout=null) {
        return on("PUT", signature, callback, timeout);
    }

    // ------------------- AUTHORIZATION -------------------//

    /**
     * Register a handler for request authorization.
     *
     * @param {Function} callback - The handler that will process authorization requests.
     *
     * @returns {object} The Rocky instance (this).
    */
    function authorize(callback) {
        _handlers.authorize <- callback;
        return this;
    }

    /**
     * Register a handler for processing rejected requests.
     *
     * @param {function} callback - The handler that will process rejected requests.
     *
     * @returns {object} The Rocky instance (this).
    */
    function onUnauthorized(callback) {
        _handlers.onUnauthorized <- callback;
        return this;
    }

    // -------------------      EVENTS    -------------------//

    /**
     * Register a handler for timed out requests.
     *
     * @param {function} callback - The handler that will process request time-outs.
     * @param {integer/float}  timeout  - Optional timeout in seconds. Default: the class-level value.
     *
     * @returns {object} The Rocky instance (this).
    */
    function onTimeout(callback, timeout = null) {
        if (timeout == null) timeout = _timeout;
        // ADDED 3.0.0 -- enforce timeout type
        if (typeof timeout != "integer" && typeof timeout != "float") throw ROCKY_ERROR.TIMEOUT;
        _handlers.onTimeout <- callback;
        _timeout = timeout;
        return this;
    }

    /**
     * Register a handler for requests asking for missing resources.
     *
     * @param {function} callback - The handler that will process 'resource not found' requests.
     *
     * @returns {object} The Rocky instance (this).
    */
    function onNotFound(callback) {
        _handlers.onNotFound <- callback;
        return this;
    }

    /**
     * Register a handler for requests that triggered an exception.
     *
     * @param {function} callback - The handler that will process the failed request.
     *
     * @returns {object} The Rocky instance (this).
    */
    function onException(callback) {
        _handlers.onException <- callback;
        return this;
    }

    // -------------------  MIDDLEWARES  -------------------//

    /**
     * Register one or more user-defined request-processing middlewares.
     *
     * @param {function/array} middlewares - One or more middleware function references.
     *
     * @returns {object} The Rocky instance (this).
    */
    function use(middlewares) {
        if (typeof middlewares == "function") {
            _handlers.middlewares.push(middlewares);
        } else if (typeof _handlers.middlewares == "array") {
            foreach (middleware in middlewares) use(middleware);
        } else {
            throw ROCKY_ERROR.MIDDLEWARE;
        }

        return this;
    }

    //-------------------- PRIVATE METHODS --------------------//

    /**
     * Apply default headers to the specified reponse object.
     *
     * @param {object} res - An imp API HTTPResponse instance.
     *
     * @private
    */
    function _addAccessControl(res) {
        res.header("Access-Control-Allow-Origin", "*")
        res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
        res.header("Access-Control-Allow-Methods", "POST, PUT, GET, OPTIONS");
    }

    /**
     * The core Rocky incoming HTTP request handler.
     *
     * @param {object} req - The source imp API HTTPRequest object.
     * @param {object} res - An imp API HTTPResponse object primed to respond to the request.
     *
     * @private
    */
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
            context.send(400, ROCKY_PARSE_ERROR);
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

            if (route.handler.hasHandler("onTimeout")) onTimeout = route.handler.getHandler("onTimeout");

            context.setTimeout(timeout, onTimeout);
            route.handler.execute(context, _handlers);
        } else {
            // if we don't have a handler
            _handlers.onNotFound(context);
        }
    }

    /**
     * Parse an HTTP request's body based on the request's content type.
     *
     * @param {object} req - The source imp API HTTPRequest object.
     *
     * @returns {string} The parsed request body.
     *
     * @private
    */
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
                throw ROCKY_ERROR.NO_BOUNDARY;
            }

            // Remove all carriage returns from string (to support either \r\n or \n for linebreaks)
            local body = "";
            local bodyLines = split(req.body, "\r");
            foreach (i, line in bodyLines) body += line;

            // Find all boundaries in the body
            local boundaries = [];
            local bregex = regexp2(@"--" + boundary);
            local bmatch = bregex.search(body);
            while (bmatch != null) {
                boundaries.push(bmatch);
                bmatch = bregex.search(body, bmatch.begin+1);
            }

            // Create array of parts
            for (local i = 0; i < boundaries.len() - 1; i++) {
                // Extract one part from the request
                local part = body.slice(boundaries[i].end + 1, boundaries[i+1].begin);

                // Split the part into headers and body
                local partSplit = regexp2("\n\n").search(part);
                local header = part.slice(0, partSplit.begin);
                local data = part.slice(partSplit.end, -1);

                // Create table to store the parsed content of the part
                local parsedPart = {};
                parsedPart.name <- null;
                parsedPart.data <- data;

                // Extract each individual header and store in parsedPart
                local keyValueRegex = regexp2(@"(^|\W)(\S+)\s*[=:]\s*(""[^""]*""|\S*)");
                local keyValueCapture = keyValueRegex.capture(header);
                while (keyValueCapture != null) {
                    // Extract key and value for the header
                    local key = header.slice(keyValueCapture[2].begin, keyValueCapture[2].end);
                    local val = header.slice(keyValueCapture[3].begin, keyValueCapture[3].end);

                    // Remove any quotations
                    if (val[0] == '"') val = val.slice(1, -1);

                    // Save the header in parsedPart
                    parsedPart[key] <- val;
                    keyValueCapture = keyValueRegex.capture(header, keyValueCapture[0].end);
                }

                // Add the parsed part to the array of parts
                parts.push(parsedPart);
            }

            // Return the array of parts
            return parts;
        }

        // Nothing matched, send back the original body
        return req.body;
    }

    /**
     * Parse an HTTP request's authorization credentials.
     *
     * @param {object} context - The Rocky.Context containing the HTTPRequest.
     *
     * @returns {table} The parsed authorization credentials.
     *
     * @private
    */
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

    /**
     * Separate out the components of a request's target path.
     *
     * @param {object} routeHandler - The Rocky.Route instance describing an endpoint.
     * @param {string} path         - The endpoint path.
     * @param {object} regexp       - An imp API Regexp instance. Default: null.
     *
     * @returns {table} The parsed path components.
     *
     * @private
    */
    function _extract_parts(routeHandler, path, regexp = null) {
        // Set up the table we will return
        local parts = { path = [], matches = [], handler = routeHandler };

        // Split the path into parts
        foreach (part in split(path, "/")) parts.path.push(part);

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

    /**
     * Process regular expression matches against an endpoint path.
     *
     * @param {object} req - The source imp API HTTPRequest object.
     *
     * @returns {table} The processed components, or null.
     *
     * @private
    */
    function _handler_match(req) {
        local signature = req.path.tolower();
        local verb = req.method.toupper();

        // ignore trailing /s if _strictRouting == false
        if (!_strictRouting) {
            while (signature.len() > 1 && signature[signature.len() - 1] == '/') {
                signature = signature.slice(0, signature.len() - 1);
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

    /**
     * Process authorization requests: just accept the request.
     *
     * @param {object} context - The Rocky.Context containing the request.
     *
     * @returns {Bool} Always authorized (true)
     *
     * @private
    */
    function _defaultAuthorizeHandler(context) {
        return true;
    }

    /**
     * Process rejected requests: issue a 401 response.
     *
     * @param {object} context - The Rocky.Context containing the request.
     *
     * @private
    */
    function _defaultUnauthorizedHandler(context) {
        context.send(401, "Unauthorized");
    }

    /**
     * Process requests to missing resources: issue a 404 response.
     *
     * @param {object} context - The Rocky.Context containing the request.
     *
     * @private
    */
    function _defaultNotFoundHandler(context) {
        context.send(404, format("No handler for %s %s", context.req.method, context.req.path));
    }

    /**
     * Process timed out requests: issue a 500 response.
     *
     * @param {object} context - The Rocky.Context containing the request.
     *
     * @private
    */
    function _defaultTimeoutHandler(context) {
        context.send(500, format("Agent Request timed out after %i seconds.", _timeout));
    }

    /**
     * Process requests that trigger exceptions: issue a 500 response.
     *
     * @param {object} context - The Rocky.Context containing the request.
     * @param {String} ex      - The triggered exception/error message.
     *
     * @private
    */
    function _defaultExceptionHandler(context, ex) {
        server.error(ex);
        context.send(500, "Agent Error: " + ex);
    }
}


/**
 * This class defines a handler for an event, eg. request authorization, time out or
 * a triggered exception, or some other, user-defined action (ie. a 'middleware').
 *
 * @copyright Electric Imp, Inc. 2015-19
 * @license   MIT
 *
 * @class
 *
*/
class Rocky.Route {

    //------------------ PRIVATE PROPERTIES ------------------//
    _handlers = null;
    _timeout = null;
    _callback = null;

    /**
     * The Rocky.Route constructor. Not called by user code, only by Rocky instances.
     *
     * @constructor
     *
     * @param {function} callback - The endpoint handler.
     *
     * returns {object} The Rocky.Route instance (this).
     *
    */
    constructor(callback) {
        _handlers = { middlewares = [] };
        _timeout = 10;
        _callback = callback;
    }

    //-------------------- PUBLIC METHODS --------------------//

    /**
     * Run the registered handlers (or defaults where no handlers are registered).
     *
     * @param {object} context        - The Rocky.Context containing the request.
     * @param {Array} defaultHandlers - The currently registered handlers.
     *
    */
    function execute(context, defaultHandlers) {
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

    /**
     * Register a route-level authorization handler.
     *
     * @param {function} callback - The handler that will process route-level requests.
     *
     * @returns {object} The target Rocky.route instance (this).
    */
    function authorize(callback) {
        return _setHandler("authorize", callback);
    }

    /**
     * Register a route-level 'request rejected' handler.
     *
     * @param {function} callback - The handler that will process route-level requests.
     *
     * @returns {object} The target Rocky.route instance (this).
    */
    function onUnauthorized(callback) {
        return _setHandler("onUnauthorized", callback);
    }

    /**
     * Register a route-level authorization handler.
     *
     * @param {function} callback - The handler that will process route-level requests.
     *
     * @returns {object} The target Rocky.route instance (this).
    */
    function onException(callback) {
        return _setHandler("onException", callback);
    }

    /**
     * Register a route-level request timeout handler.
     *
     * @param {function} callback - The handler that will process route-level requests.
     * @param {integer}  timeout  - The timeout period in seconds.
     *
     * @returns {object} The target Rocky.route instance (this).
    */
    function onTimeout(callback, timeout = null) {
        if (timeout == null) timeout = _timeout;
        // ADDED 3.0.0 -- enforce timeout type
        if (typeof timeout != "integer" && typeof timeout != "float") throw ROCKY_ERROR.TIMEOUT;
        _timeout = timeout;
        return _setHandler("onTimeout", callback);
    }

    /**
     * Register a route-level middleware.
     *
     * @param {function/array} middlewares - One or more references to middlware functions.
     *
     * @returns {object} The target Rocky.route instance (this).
    */
    function use(middlewares) {
        if (!hasHandler("middlewares")) { _handlers["middlewares"] <- [] };

        if(typeof middlewares == "function") {
            _handlers.middlewares.push(middlewares);
        } else if (typeof _handlers.middlewares == "array") {
            foreach(middleware in middlewares) use(middleware);
        } else {
            throw ROCKY_ERROR.MIDDLEWARE;
        }

        return this;
    }

    /**
     * Determine if a specified handler has been registered.
     *
     * @param {string} handlerName - The name of the handler.
     *
     * @returns {Bool} Whether the named handler is registered (true) or not (false).
    */
    function hasHandler(handlerName) {
        return (handlerName in _handlers);
    }

    /**
     * Get a specified handler.
     *
     * @param {string} handlerName - The name of the handler.
     *
     * @returns {function} A reference to the handler.
    */
    function getHandler(handlerName) {
        // Return null if no handler
        if (!hasHandler(handlerName)) return null;

        // Return the handler if it exists
        return _handlers[handlerName];
    }

    /**
     * Get the route-level request timeout.
     *
     * @returns {integer} The timeout period in seconds.
    */
    function getTimeout() {
        return _timeout;
    }

    /**
     * Set the route-level request timeout.
     *
     * @param {integer} The timeout period in seconds.
    */
    function setTimeout(timeout) {
        return _timeout = timeout;
    }

    //-------------------- PRIVATE METHODS --------------------//

    /**
     * Invoke the next middleware, and move the authorize/callback/onUnauthorized
     * flow on when any registered middlewares have completed.
     *
     * @param {object}  context - The Rocky.Context instance containing the request.
     * @param {integer} idx     - Index counter for the handler list.
     *
     * @private
    */
    function _invokeNextHandler(context, idx = 0) {
        // If we've sent a response, we're done
        if (context.isComplete()) return;

        // Check if we have middlewares left to execute
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
                    // if we're unauthorized, execute the onUnauthorized handler
                    _handlers.onUnauthorized(context);
                }
            } catch (ex) {
                _handlers.onException(context, ex);
            }
        }
    }

    /**
     * Generate 'next()' functions for middlewares. These are supplied to handlers so
     * that they can invoke the next handler in the sequence.
     *
     * @param {object}  context - The Rocky.Context instance containing the request.
     * @param {integer} idx     - Index counter for the handler list.
     *
     * @returns {function} The next function to excecute in the middlware sequence.
     *
     * @private
    */
    function _nextGenerator(context, idx) {
        return function() { _invokeNextHandler(context, idx); }.bindenv(this);
    }

    //
    /**
     * Set a handler (used internally to simplify code).
     *
     * @param {string}   handlerName - The name of the handler.
     * @param {function} callback    - The function to be assigned to that name.
     *
     * @returns {object} The target Rocky.Route instance (this).
     *
     * @private
    */
    function _setHandler(handlerName, callback) {
        // Create handler slot if required
        if (!hasHandler(handlerName)) { _handlers[handlerName] <- null; }

        // Set the handler
        _handlers[handlerName] = callback;

        return this;
    }
}

/**
 * This class defines a Rocky request context, which combines the core imp API request
 * and response objects with extracted data (eg. path, authorization), user-defined data,
 * and housekeeping information (eg. whether the context has responded).
 *
 * @copyright Electric Imp, Inc. 2015-19
 * @license   MIT
 *
 * @class
 *
*/

class Rocky.Context {

    // ------------------ PUBLIC PROPERTIES ------------------//
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

    /**
     * The Rock.Context constructor. Not called by user code, only by Rocky instances.
     *
     * @constructor
     *
     * @param {object} _req - An imp API HTTPRequest instance.
     * @param {object} _res - An imp API HTTPResponse instance.
     *
     * returns {object} A Rocky.Context instance.
     *
    */
    constructor(_req, _res) {
        req = _req;
        res = _res;
        sent = false;
        time = date();
        userdata = {};

        // Set the context's identify and then store it
        do {
            id = math.rand();
        } while (id in _contexts);
        _contexts[id] <- this;
    }

    //-------------------- STATIC METHODS --------------------//

    /**
     * Get the context identified by the specified ID.
     *
     * @param {integer} id - A Rocky.Context identifier.
     *
     * @returns {object} The requested Rocky.Context instance, or null.
     *
    */
    static function get(id) {
        if (id in _contexts) {
            return _contexts[id];
        } else {
            return null;
        }
    }

    /**
     * Send a response to all current contexts. This closes but does not delete all contexts.
     *
     * @param {integer} statuscode - The response's HTTP status code.
     * @param {string}  response   - The response body.
     * @param {table}   headers    - Optional additional response headers. Default: no additional headers.
     *
    */
    static function sendToAll(statuscode, response, headers = {}) {
        // Send to all active contexts
        foreach (key, context in _contexts) {
            foreach (k, header in headers) {
                context.setHeader(k, header);
            }
            context._doSend(statuscode, response);
        }

        // Remove all contexts after sending
        _contexts.clear();
    }

    //-------------------- PUBLIC METHODS --------------------//

    /**
     * Does the request include the 'accept' header with the 'text/html' mime type?
     *
     * @returns {Bool} true if the request has 'accept: text/html'
     *
    */
    function isbrowser() {
        return (("accept" in req.headers) && (req.headers.accept.find("text/html") != null));
    }

    // ADDED 3.0.0
    // lowerCamelCase version of the above call. Keep the old one to
    // minimize the incompatibility, but document/recommend the new form
    function isBrowser() {
        return isbrowser();
    }

    /**
     * Get the value of the specified header.
     *
     * @param {string} key - The header name.
     * @param {string} def - A default value for non-existent headers. Default: null
     *
     * @returns {string} The value or the default.
     *
    */
    function getHeader(key, def = null) {
        key = key.tolower();
        if (key in req.headers) return req.headers[key];
        else return def;
    }

    /**
     * Set the value of the specified header.
     *
     * @param {string} key   - The header name.
     * @param {string} value - The header's assigned value.
     *
    */
    function setHeader(key, value) {
        return res.header(key, value);
    }

    /**
     * Send the context's response. This does not delete the context but
     * removes it from the store.
     * Supports two forms: 'send(statuscode, message)' and 'send(message)'.
     *
     * @param {integer} code      - The response's HTTP status code or its body
     * @param {string}  message   - The response's body.
     * @param {bool}    forcejson - Mandate that the body is JSON-encoded.
     *
    */
    function send(code, message = null, forcejson = false) {
        _doSend(code, message, forcejson);

        // Remove the context from the store
        if (id in _contexts) delete Rocky.Context._contexts[id];
    }

    /**
     * Set the context timeout.
     *
     * @param {integer}  timeout  - The timeout period in seconds.
     * @param {function} callback - The timeout handler.
     *
    */
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

    /**
     * Determine if the context's response has been sent.
     *
     * @returns {Bool} true if the context's response has been sent, otherwise false.
     *
    */
    function isComplete() {
        return sent;
    }

    //-------------------- PRIVATE METHODS --------------------//

    /**
     * Send the context's response. Handles both 'send(message)' and 'send(code, message)'
     *
     * @param {integer/any} code      - The response's HTTP status code, or body
     * @param {any}         message   - The response's body.
     * @param {bool}        forcejson - Mandate that the body is JSON-encoded. Default: false.
     *
     * @private
    */
    function _doSend(code, message = null, forcejson = false) {
        // Cancel the timeout
        if (timer) {
            imp.cancelwakeup(timer);
            timer = null;
        }

        // Has this context been closed already?
        if (sent) return false;

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

}
