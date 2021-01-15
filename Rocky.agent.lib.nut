enum ROCKY_ERROR {
    PARSE = "Error parsing body of request",
    BAD_MIDDLEWARE = "Invalid middleware -- middleware must be a function",
    TIMEOUT = "Bad timeout value - must be an integer or float",
    NO_BOUNDARY = "No boundary found in content-type",
    BAD_CALLBACK = "Invald callback -- callback must be a function"
}

/**
 * This class allows you to define and operate an agent-served API.
 *
 * @copyright 2015-19 Electric Imp
 * @copyright 2020-21 Twilio
 * @license   MIT
 *
 * @table
 *
*/
Rocky <- {

    "VERSION": "3.0.1",

    // ------------------ PRIVATE PROPERTIES ------------------//

    // Route handlers, event handers and middleware
    // are all stored in the same table
    "_handlers": null,

    // Settings
    "_timeout": 10,
    "_strictRouting": false,
    "_allowUnsecure": false,
    "_accessControl": true,
    "_sigCaseSensitive": false,

    /**
     * The Rocky initializer. In 3.0.0, this replaces the class constructor.
     *
     * @constructor
     *
     * @param {table} settings - Optional instance behavior settings. Default: see values above.
     *
     * @returns {table} Rocky.
     *
    */
    "init": function(settings = {}) {
        // Set defaults on a re-call
        _setDefaults();

        // Initialize settings, checking values as appropriate
        if ("timeout" in settings && (typeof settings.timeout == "integer" || typeof settings.timeout == "float")) _timeout = settings.timeout;
        if ("allowUnsecure" in settings && typeof settings.allowUnsecure == "bool") _allowUnsecure = settings.allowUnsecure;
        if ("strictRouting" in settings && typeof settings.strictRouting == "bool") _strictRouting = settings.strictRouting;
        if ("accessControl" in settings && typeof settings.accessControl == "bool") _accessControl = settings.accessControl;
        if ("sigCaseSensitive" in settings && typeof settings.sigCaseSensitive == "bool") _sigCaseSensitive = settings.sigCaseSensitive;

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
        http.onrequest(Rocky._onrequest.bindenv(this));

        return this;
    },

    //-------------------- STATIC METHODS --------------------//

    /**
     * Get the specified Rocky context.
     *
     * @param {integer} id - The identifier of the desired context.
     *
     * @returns {object} The requested Rocky.Context instance.
    */
    "getContext": function(id) {
        return Rocky.Context.get(id);
    },

    /**
     * Send a response to to all currently active requests.
     *
     * @param {integer} statuscode - The response's HTTP status code.
     * @param {any}     response   - The response body.
     * @param {table}   headers    - Optional additional response headers. Default: no additional headers.
     *
    */
    "sendToAll": function(statuscode, response, headers = {}) {
        Rocky.Context.sendToAll(statuscode, response, headers);
    },

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
    "on": function(verb, signature, callback, timeout = null) {
        // Check timeout and set it to class-level timeout if not specified for route
        if (timeout == null) timeout = this._timeout;

        // Register this verb and signature against the callback
        verb = verb.toupper();
        // ADDED 3.0.0 -- Manage signature case (see https://github.com/electricimp/Rocky/issues/36)
        if (!_sigCaseSensitive) signature = signature.tolower();
        if (!(signature in _handlers)) _handlers[signature] <- {};

        local routeHandler = Rocky.Route(callback);
        routeHandler.setTimeout(timeout);
        _handlers[signature][verb] <- routeHandler;
        return routeHandler;
    },

    /**
     * Register a handler for an HTTP POST request.
     *
     * @param {string}   signature - An endpoint path signature.
     * @param {function} callback  - The handler that will process the POST request.
     * @param {integer}  timeout   - Optional timeout in seconds. Default: the class-level value.
     *
     * @returns {object} A Rocky.Route instance for the handler.
    */
    "post": function(signature, callback, timeout = null) {
        return on("POST", signature, callback, timeout);
    },

    /**
     * Register a handler for an HTTP GET request.
     *
     * @param {string}   signature - An endpoint path signature.
     * @param {function} callback  - The handler that will process the GET request.
     * @param {integer}  timeout   - Optional timeout in seconds. Default: the class-level value.
     *
     * @returns {object} A Rocky.Route instance for the handler.
    */
    "get": function(signature, callback, timeout = null) {
        return on("GET", signature, callback, timeout);
    },

    /**
     * Register a handler for an HTTP PUT request.
     *
     * @param {string}   signature - An endpoint path signature.
     * @param {function} callback  - The handler that will process the PUT request.
     * @param {integer}  timeout   - Optional timeout in seconds. Default: the class-level value.
     *
     * @returns {object} A Rocky.Route instance for the handler.
    */
    "put": function(signature, callback, timeout = null) {
        return on("PUT", signature, callback, timeout);
    },

    // ------------------- AUTHORIZATION -------------------//

    /**
     * Register a handler for request authorization.
     *
     * @param {Function} callback - The handler that will process authorization requests.
     *
     * @returns {object} The Rocky instance (this).
    */
    "authorize": function(callback) {
        _handlers.authorize <- callback;
        return this;
    },

    /**
     * Register a handler for processing rejected requests.
     *
     * @param {function} callback - The handler that will process rejected requests.
     *
     * @returns {object} The Rocky instance (this).
    */
    "onUnauthorized": function(callback) {
        _handlers.onUnauthorized <- callback;
        return this;
    },

    // -------------------      EVENTS    -------------------//

    /**
     * Register a handler for timed out requests.
     *
     * @param {function} callback - The handler that will process request time-outs.
     * @param {integer/float}  timeout  - Optional timeout in seconds. Default: the class-level value.
     *
     * @returns {object} The Rocky instance (this).
    */
    "onTimeout": function(callback, timeout = null) {
        if (timeout != null) _timeout = timeout;
        _handlers.onTimeout <- callback;
        return this;
    },

    /**
     * Register a handler for requests asking for missing resources.
     *
     * @param {function} callback - The handler that will process 'resource not found' requests.
     *
     * @returns {object} The Rocky instance (this).
    */
    "onNotFound": function(callback) {
        _handlers.onNotFound <- callback;
        return this;
    },

    /**
     * Register a handler for requests that triggered an exception.
     *
     * @param {function} callback - The handler that will process the failed request.
     *
     * @returns {object} The Rocky instance (this).
    */
    "onException": function(callback) {
        _handlers.onException <- callback;
        return this;
    },

    // -------------------  MIDDLEWARES  -------------------//

    /**
     * Register one or more user-defined request-processing middlewares.
     *
     * @param {function/array} middlewares - One or more middleware function references.
     *
     * @returns {object} The Rocky instance (this).
    */
    "use": function(middlewares) {
        if (typeof middlewares == "function") {
            _handlers.middlewares.push(middlewares);
        } else if (typeof _handlers.middlewares == "array") {
            foreach (middleware in middlewares) use(middleware);
        } else {
            throw ROCKY_ERROR.BAD_MIDDLEWARE;
        }

        return this;
    },

    //-------------------- PRIVATE METHODS --------------------//

    /**
     * Apply default headers to the specified reponse object.
     *
     * @param {object} res - An imp API HTTPResponse instance.
     *
     * @private
    */
    "_addAccessControl": function(res) {
        res.header("Access-Control-Allow-Origin", "*")
        res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
        res.header("Access-Control-Allow-Methods", "POST, PUT, GET, OPTIONS");
    },

    /**
     * The core Rocky incoming HTTP request handler.
     *
     * @param {object} req - The source imp API HTTPRequest object.
     * @param {object} res - An imp API HTTPResponse object primed to respond to the request.
     *
     * @private
    */
    "_onrequest": function(req, res) {
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
            context.send(400, ROCKY_ERROR.PARSE);
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

            context.setTimeout(timeout, onTimeout, _handlers.onException);
            route.handler.execute(context, _handlers);
        } else {
            // If we don't have a handler
            // FROM 3.0.0 -- manage exceptions thrown in the handler
            try {
                _handlers.onNotFound(context);
            } catch (ex) {
                _handlers.onException(context, ex);
            }
        }
    },

    /**
     * Parse an HTTP request's body based on the request's content type.
     *
     * @param {object} req - The source imp API HTTPRequest object.
     *
     * @returns {string} The parsed request body.
     *
     * @private
    */
    "_parse_body": function (req) {
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
    },

    /**
     * Parse an HTTP request's authorization credentials.
     *
     * @param {object} context - The Rocky.Context containing the HTTPRequest.
     *
     * @returns {table} The parsed authorization credentials.
     *
     * @private
    */
    "_parse_authorization": function(context) {
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
    },

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
    "_extract_parts": function(routeHandler, path, regexp = null) {
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
    },

    /**
     * Process regular expression matches against an endpoint path.
     *
     * @param {object} req - The source imp API HTTPRequest object.
     *
     * @returns {table} The processed components, or null.
     *
     * @private
    */
    "_handler_match": function(req) {
        // ADDED 3.0.0 -- manage signature case (see https://github.com/electricimp/Rocky/issues/36)
        local signature = req.path;
        if (!_sigCaseSensitive) signature = signature.tolower();
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
    },

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
    "_defaultAuthorizeHandler": function(context) {
        return true;
    },

    /**
     * Process rejected requests: issue a 401 response.
     *
     * @param {object} context - The Rocky.Context containing the request.
     *
     * @private
    */
    "_defaultUnauthorizedHandler": function(context) {
        context.send(401, "Unauthorized");
    },

    /**
     * Process requests to missing resources: issue a 404 response.
     *
     * @param {object} context - The Rocky.Context containing the request.
     *
     * @private
    */
    "_defaultNotFoundHandler": function(context) {
        context.send(404, format("No handler for %s %s", context.req.method, context.req.path));
    },

    /**
     * Process timed out requests: issue a 500 response.
     *
     * @param {object} context - The Rocky.Context containing the request.
     *
     * @private
    */
    "_defaultTimeoutHandler": function(context) {
        context.send(500, format("Agent Request timed out after %i seconds.", _timeout));
    },

    /**
     * Process requests that trigger exceptions: issue a 500 response.
     *
     * @param {object} context - The Rocky.Context containing the request.
     * @param {String} ex      - The triggered exception/error message.
     *
     * @private
    */
    "_defaultExceptionHandler": function(context, ex) {
        server.error(ex);
        context.send(500, "Agent Error: " + ex);
    },

    /**
     * Set Rocky defaults.
     *
     * @private
    */
    "_setDefaults": function() {
        _timeout = 10;
        _strictRouting = false;
        _allowUnsecure = false;
        _accessControl = true;
        _sigCaseSensitive = false;
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
     * NOTE This is public because it is used outside of the class (ie. by the Rocky singleton),
     *      but it is not expected to be called directly by application code, so is not
     *      formally documented.
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
        if (typeof callback != "function") throw ROCKY_ERROR.BAD_CALLBACK;
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
        if (typeof callback != "function") throw ROCKY_ERROR.BAD_CALLBACK;
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
        if (typeof callback != "function") throw ROCKY_ERROR.BAD_CALLBACK;
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
        if (typeof callback != "function") throw ROCKY_ERROR.BAD_CALLBACK;
        if (timeout != null) _timeout = timeout;
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
            throw ROCKY_ERROR.BAD_MIDDLEWARE;
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
                _handlers.middlewares[idx](context, _nextGenerator(context, idx + 1));
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
     * @param {function} exceptionHandler - An error handler.
     *
    */
    function setTimeout(timeout, callback = null, exceptionHandler = null) {
        // Set the timeout timer
        if (timer) imp.cancelwakeup(timer);
        timer = imp.wakeup(timeout, function() {
            if (callback == null) {
                send(504, "Timeout");
            } else {
                try {
                    callback(this);
                } catch(ex) {
                    if (exceptionHandler != null) exceptionHandler(this, ex);
                }
            }
        }.bindenv(this));
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
