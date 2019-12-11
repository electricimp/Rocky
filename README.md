# Rocky 3.0.0 #

Rocky is an framework for building powerful and scalable APIs for your imp-powered products.

**Important** From version 3.0.0, Rocky is implemented as a table rather than a class. **This is a breaking change**. This change has been made to ensure that Rocky is available solely as a singleton. For full details on updating your code, please see [**Rocky Usage**](#rocky-usage), below.

![Build Status](https://cse-ci.electricimp.com/app/rest/builds/buildType:(id:Rocky_BuildAndTest)/statusIcon)

The Rocky library consists of the following components:

- [Rocky](#rocky) &mdash; The core application, used to create routes, set default handlers, etc.
  - *Singleton Methods*
    - [Rocky.init()](#rocky_init) &mdash; Initializes the singleton and prepares it for use.
    - [Rocky.get()](#rocky_verb) &mdash; Creates a handler for GET requests that match the specified signature.
    - [Rocky.put()](#rocky_verb) &mdash; Creates a handler for PUT requests that match the specified signature.
    - [Rocky.post()](#rocky_verb) &mdash; Creates a handler for POST requests that match the specified signature.
    - [Rocky.on()](#rocky_on) &mdash; Creates a handler for requests that match the specified verb and signature.
    - [Rocky.use()](#rocky_use) &mdash; Binds one or more middlewares to all routes.
    - [Rocky.authorize()](#rocky_authorize) &mdash; Specify the default `authorize` handler for all routes.
    - [Rocky.onUnauthorized()](#rocky_onunauthorized) &mdash; Specify the default `onUnauthorized` callback for all routes.
    - [Rocky.onTimeout()](#rocky_ontimeout) &mdash; Set the default `onTimeout` handler for all routes.
    - [Rocky.onNotFound()](#rocky_onnotfound) &mdash; Set the default `onNotFound` handler for all routes.
    - [Rocky.onException()](#rocky_onexception) &mdash; Set the default `onException` handler for all routes.
    - [Rocky.getContext()](#rocky_getcontext) &mdash; Retrieve a [Rocky.Context](#context) object by its ID.
    - [Rocky.sendToAll()](#rocky_sendtoall) &mdash; Send a response to *all* open requests.
- [Rocky.Route](#route) &mdash; A handler for a specific route.
  - *Instance Methods*
    - [Rocky.Route.use()](#route_use) -&mdash; Binds one or more middlewares to the route.
    - [Rocky.Route.authorize()](#route_authorize) &mdash; Specify the default `authorize` handler for the route.
    - [Rocky.Route.onUnauthorized()](#route_onunauthorized) &mdash; Specify the default `onUnauthorized` callback for the route.
    - [Rocky.Route.onTimeout()](#route_ontimeout) &mdash; Set the default `onTimeout` handler for the route.
    - [Rocky.Route.onException()](#route_onexception) &mdash; Set the default `onException` handler for the route.
    - [Rocky.Route.hasHandler()](#route_hashandler) &mdash; Determine if the route has a named handler registered.
    - [Rocky.Route.getHandler()](#route_gethandler) &mdash; Get a named handler.
    - [Rocky.Route.getTimeout()](#route_gettimeout) &mdash; Retrieve the current route-specific timeout setting.
    - [Rocky.Route.setTimeout()](#route_settimeout) &mdash; Set a new route-level timeout.
- [Rocky.Context](#context) - The information passed into a route handler.
  - *Instance Methods*
    - [Rocky.Context.send()](#context_send) &mdash; Sends an HTTP response.
    - [Rocky.Context.isComplete()](#context_iscomplete) &mdash; Returns whether a response has been sent for the current context.
    - [Rocky.Context.getHeader()](#context_getheader) &mdash; Attempts to get the specified header from the request object.
    - [Rocky.Context.setHeader()](#context_setheader) &mdash; Sets the specified header in the response object.
    - [Rocky.Context.setTimeout()](#context_settimeout) &mdash; Set a context timeout.
    - [Rocky.Context.isBrowser()](#context_isbrowser) &mdash; Returns `true` if the request contains an `Accept: text/html` header.
  - *Class Methods*
    - [Rocky.Context.get()](#context_get) &mdash; Class method that can retrieve a specific context.
    - [Rocky.Context.sendToAll()](#context_sendtoall) &mdash; Class method that sends a response to *all* open requests/contexts.
  - *Properties*
    - [Rocky.Context.req](#context_req) &mdash; The HTTP Request Table.
    - [Rocky.Context.id](#context_id) &mdash; The context's unique ID.
    - [Rocky.Context.path](#context_path) &mdash; The full path the request was made to.
    - [Rocky.Context.matches](#context_matches) &mdash; An array of matches to the path's regular expression.
    - [Rocky.Context.userdata](#context_userdata) &mdash; A field developers can use to store data during long running tasks, etc
- [Middleware](#middleware) - Used to transform and verify data before the main request handler.
  - [Order of Execution](#middleware_orderofexecution) &mdash; Explanation of the execution flow for middleware and event handlers.
- [CORS Requests](#cors_requests) &mdash; How to handle cross-site HTTP requests ([CORS](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing)).

<a id="rocky"></a>

## Rocky Usage ##

Rocky 3.0.0 is implemented as a table to enforce singleton behavior. You code should no longer instantiate Rocky using a constructor call, but instead call the new *init()* method to initialize the library.

All of Rocky’s methods are accessible as before, and return the same values. *init()* returns a reference to the Rocky singleton. There is no longer a distinction between class and instance methods: all of Rocky’s methods can be called on Rocky itself, or an alias variables, as these reference the same table:

```squirrel
// These calls are equivalent
app.get("/users/([^/]*)", function(context) {
    local username = context.matches[1];
});

Rocky.get("/users/([^/]*)", function(context) {
    local username = context.matches[1];
});
```

**Note** [Rocky.Context](#context) and [Rocky.Route](#route) continue to be implemented as classes, but remember that you will not be creating instances of these classes yourself &mdash; new instances will be made available to you as needed, by Rocky.

## Rocky Methods ##

<h3 id="rocky_init">init(<i>[settings]</i>)</h3>

The new *init()* method takes the same argument as the former constructor: an optional [table of settings](#initialization-options).

Even if your code doesn’t alter Rocky’s default behavior, you still need to call *init()* in order to ensure that the table is correctly initialized for use. If you call *init()* again, the default settings and event handlers will be re-applied.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *settings* | Table | No | See [**Initialization Options**](#initialization-options) for details and setting defaults |

#### Initialization Options ####

A table containing any of the following keys may be passed into *init()* to modify the library’s default behavior:

| Key | Description |
| --- | --- |
| *accessControl* | Modifies whether Rocky will automatically add `Access-Control` headers to the response object. Default: `true` |
| *allowUnsecure* | Modifies whether Rocky will accept HTTP requests. Default: `false` (ie. HTTPS only) |
| *strictRouting* | Enables or disables strict routing. Default: `false` (ie. Rocky will consider `/foo` and `/foo/` to be identical) |
| *sigCaseSensitive* | Enforce [signature](#signatures) case sensitivity. Default: `false` (ie. Rocky will consider `/FOO` and `/foo` to be identical) |
| *timeout* | Modifies how long Rocky will hold onto a request before automatically executing the *onTimeout* handler. Default: 10s |

#### Example ####

```squirrel
#require "rocky.agent.lib.nut:3.0.0"

local settings = { "timeout": 30 };
app <- Rocky.init(settings);
```

<div id="rocky_verb"><h3>VERB(<i>signature, callback[, timeout]</i>)</h3></div>

Rocky’s *VERB()* methods allow you to assign routes based on the specified verb and [signature](#signatures). The following *VERB()* methods are provided:

- app.get(*signature, callback[, timeout]*)
- app.put(*signature, callback[, timeout]*)
- app.post(*signature, callback[, timeout]*)

When a match is found on the verb (as specified by the method) and the signature, the callback function will be executed. The callback receives a [Rocky.Context](#context) object as its only argument.

An optional route-level timeout can be specified. If no timeout is specified, the timeout set in [the initializer](#rocky) will be used.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *signature* | String | Yes | A [signature](#signatures) defining the API endpoint |
| *callback* | Function | Yes | A function to handle the request. It receives a [Rocky.Context](#context) object |
| *timeout* | String | No | An optional request timeout in seconds. Default: the global default or [*init()*](#rocky_init)-applied timeout |

#### Returns ####

Rocky.Route &mdash; an instance representing the registered handler.

#### Example ####

```squirrel
// Responds with '200, { "message": "hello world" }'
// when the user makes a GET request to the agent URL:
app.get("/", function(context) {
    context.send({ "message": "hello world" })
})
```

<div id="rocky_on"><h3>on(<i>verb, signature, callback[, timeout]</i>)</h3></div>

This method allows you to create APIs that use verbs other than GET, PUT or POST. The *on()* method works identically to the *VERB()* methods, but you specify the verb as a string.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *verb* | String | Yes | The HTTP request verb |
| *signature* | String | Yes | A [signature](#signatures) defining the API endpoint |
| *callback* | Function | Yes | A function to handle the request. It receives a [Rocky.Context](#context) object |
| *timeout* | String | No | An optional request timeout in seconds. Default: the global default or [*init()*](#rocky_init)-applied timeout |

#### Returns ####

Rocky.Route &mdash; an instance representing the registered handler.

#### Example ####

```squirrel
// Delete a user
app.on("delete", "/users/([^/]*)", function(context) {
    // Grab the username from the regex
    // (context.matches[0] will always be the full path)
    local username = context.matches[1];

    if (username in usersTable) {
        // If we found the user, delete it and return 201
        delete usersTable[username]
        context.send(201, null);
    } else {
        // if the user doesn't exist, return a 404
        context.send(404, { "error": "Unknown User" });
    }
});
```

<div id="rocky_use"><h3>use(<i>callback</i>)</h3></div>

This method allows you to attach an application-specific handler, called a “middleware” function, or an array of middleware functions, to the global Rocky object. Please see [**Middleware**](#middleware) for more information.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function or array of functions | Yes | One or more [middleware functions](#middleware)  |

The callback function receives a [Rocky.Context](#context) object and a reference to the next middleware in sequence as its arguments. See the example below for guidance.

#### Returns ####

*this* &mdash; the target Rocky instance.

#### Example ####

```squirrel
// Create a function to add the specific CORS headers we want:
function customCORSMiddleware(context, next) {
    context.setHeader("Access-Control-Allow-Origin", "*");
    context.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    context.setHeader("Access-Control-Allow-Methods", "POST, PUT, PATCH, GET, OPTIONS");

    // Invoke the next middleware
    next();
}

app <- Rocky.init({ "accessControl": false });

// Add the middleware to the global Rocky object so every
// incoming request has the headers added
app.use([customCORSMiddleware]);

app.get("/", function(context) {
    context.send(200, { "message": "Hello World" });
});
```

<div id="rocky_authorize"><h3>authorize(<i>callback</i>)</h3></div>

This method allows you to specify a global function to validate or authorize incoming requests.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to authorize or reject the request |

The callback function takes a [Rocky.Context](#context) object as its single argument and must return either `true` (if the request is authorized) or `false` (if the request is not authorized). The callback is executed before the main request handler, so:

- If the callback returns `true`, the route handler will be invoked.
- If the callback returns `false`, the [onUnauthorized](#rocky_onunauthorized) response handler is invoked.

#### Returns ####

*this* &mdash; the target Rocky instance.

#### Example ####

```squirrel
app.authorize(function(context) {
    // Ensure user has a valid api key
    return (context.getHeader("api-key") in apiKeys);
});
```

<div id="rocky_onunauthorized"><h3>onUauthorized(<i>callback</i>)</h3></div>

This method allows you to configure the default response to requests that fail to be authorized via the callback registered with [*authorize()*](#rocky_authorize).

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to manage unauthorized requests |

The callback takes a [Rocky.Context](#context) object as its single argument and will be executed for all unauthorized requests that do not have a route-level [onUnauthorized](#route_onunauthorized) response handler.

#### Returns ####

*this* &mdash; the target Rocky instance.

#### Example ####

```squirrel
app.onUnauthorized(function(context) {
    context.send(401, { "message": "Unauthorized" });
});
```

<div id="rocky_ontimeout"><h3>onTimeout(<i>callback</i>, <i>[timeout]</i>)</h3></div>

This method allows you to configure the default response to requests that exceed the timeout.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to manage requests that timed out |
| *timeout* | Float or integer | No | Optional timeout in seconds. Default: 10s |

The callback takes a [Rocky.Context](#context) object as its single argument and will be executed for all timed out requests that do not have a route-level [onTimeout](#route_onTimeout) response handler. The callback should (but is not required to) send a response code of 408.

#### Returns ####

*this* &mdash; the target Rocky instance.

#### Example ####

```squirrel
app.onTimeout(function(context) {
    context.send(408, { "message": "Agent Timeout" });
});
```

<div id="rocky_onnotfound"><h3>onNotFound(<i>callback</i>)</h3></div>

This method allows you to configure the response handler for requests that could not match a route.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to manage requests that could not be matched to an endpoint |

The callback takes a [Rocky.Context](#context) object as its single argument. It should (but is not required to) send a response code of 404.

#### Returns ####

*this* &mdash; the target Rocky instance.

#### Example ####

```squirrel
app.onNotFound(function(context) {
    context.send(404, { "message": "The resource you're looking for doesn't exist" });
});
```

<div id="rocky_onexception"><h3>onException(<i>callback</i>)</h3></div>

This method allows you to configure the global response handler for requests that encounter runtime errors.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to manage requests that triggered runtime errors |

The callback takes a [Rocky.Context](#context) object and the exception as its arguments. See the example below for usage guidance. It will be executed for all requests that encounter runtime errors and do not have a route-level [onException](#route_onexception) handler. This method should (but is not required to) send a response code of 500.

#### Returns ####

*this* &mdash; the target Rocky instance.

#### Example ####

```squirrel
app.onException(function(context, except) {
    context.send(500, { "message": "Internal Agent Error",
                        "error":   except });
});
```

<div id="rocky_getcontext"><h3>getContext(<i>id</i>)</h3></div>

Every [Rocky.Context](#context) object created by Rocky is assigned a unique ID that can retrieved by reading its [context.id](#context_id) field. Pass such an ID into *getContext()* to retrieve previously created contexts. This method is primarily used for long-running or asynchronous requests.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *id* | String | Yes | The ID of the required context |

#### Returns ####

Nothing.

#### Example ####

In this example, we fetch the temperature from the device when the request is made.

```squirrel
// Agent Code
app.get("/temp", function(context) {
    // Send a getTemp request to the device, and pass context.id as the data
    device.send("getTemp", context.id);
});

device.on("getTempResponse", function(data) {
    // When we get a getTempResponse message, get the context
    local context = app.getContext(data.id);

    // then send the response using that context
    if (!context.isComplete()) {
        context.send(200, { "temp": data.temp });
    }
});
```

```squirrel
// Device Code
agent.on("getTemp", function(id) {
    local temp = getTemp();
    // When we get a "getTemp" message, send back a response that includes
    // the id passed to the device, and the temperature data
    agent.send("getTempResponse", { "id": id, "temp": temp });
});
```

<div id="rocky_sendtoall"><h3>sendToAll(<i>statuscode, response[, headers]</i>)</h3></div>

This method sends a response to **all** open requests. This is most useful in APIs that allow for long-polling.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *statuscode* | Integer | Yes | The response’s [HTTP status code](http://en.wikipedia.org/wiki/List_of_HTTP_status_codes) |
| *response* | String | Yes | The response’s body |
| *headers* | Table | No | Additional response headers and their values. Default: no extra headers |

#### Returns ####

Nothing.

#### Example ####

```squirrel
app.get("/poll", function(context) {
    // Do nothing
});

// When we get data - send it to all open requests
device.on("data", function(data) {
    app.sendToAll(200, data);
});
```

<div id="route"><h2>Rocky.Route Methods</h2></div>

The Rocky.Route object encapsulates the behavior associated with a request made to a specific route. You should never call the Rocky.Route constructor directly; instead, create and associate routes using Rocky’s [*get()*](#rocky_verb), [*put()*](#rocky_verb), [*post()*](#rocky_verb) and [*on()*](#rocky_on) methods.

All methods that affect the behavior of a route are designed to be used in a fluent style, ie. the methods return the route object itself, so they can be chained together. For example:

```squirrel
app.get("/", function(context) {
    context.send({ "message": "hello world" });
}).authorize(function(context) {
    return (context.getHeader("api-key") in apiKeys);
}).onUnauthorized(function(context) {
    context.send(401, { "message": "Unauthorized" });
});
```

<div id="route_use"><h3>use(<i>callback</i>)</h3></div>

This method allows you to attach a middleware function, or an array of middleware functions, to a specific route. Please see [**Middleware**](#middleware) for more information.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function or array of functions | Yes | One or more [middleware functions](#middleware) |

The callback function receives a [Rocky.Context](#context) object and a reference to the next middleware in sequence as its arguments. See the example below for guidance.

#### Returns ####

Nothing.

#### Example ####

```squirrel
app <- Rocky.init();

// Custom Middleware to validate new users
function validateNewUserMiddleware(context, next) {
    // Make sure they supplied a username nas password
    if (!("username" in context.req.body)) context.send(400, "Required parameter 'username' missing");
    if (!("passwordHash" in context.req.body)) context.send(400, "Required parameter 'passwordHash' missing");

    // Ensure the username is unique
    if (context.req.body.username in usernames) context.send(400, "Requested username already exists");

    // Invoke the next middleware
    next();
}

app.post("/users", function(context) {
    // We know the required fields exist because we've attached a middleware
    // to check for them
    usernames[context.req.body.username] <- context.req.body.passwordHash;
    context.send(200, "OK");
}).use([ validateNewUserMiddleware ]);
```

<div id="route_authorize"><h3>authorize(<i>callback</i>)</h3></div>

This method allows you to specify a route-level function to validate or authorize incoming requests. Such a route-level authorization handler will override the global authorization handler set by Rocky’s [*authorize()*](#rocky_authorize) method for requests made to the specified route.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to authorize or reject the request |

The callback function receives a [Rocky.Context](#context) object as its single argument and must return either `true` (if the request is authorized) or `false` (if the request is not authorized). The callback is executed before the main request handler, so:

- If the callback returns `true`, the route handler will be invoked.
- If the callback returns `false`, the route-specific [onUnauthorized](#route_onunauthorized) response handler is invoked. If there is no route-specific [onUnauthorized](#route_onunauthorized) response handler, the global [onUnauthorized](#rocky_onunauthorized) response handler is invoked.

#### Returns ####

Nothing.

#### Example ####

```squirrel
// Delete a user
app.on("delete", "/users/([^/]*)", function(context) {
    // Grab the username from the regex
    local username = context.matches[1];

    delete users[username];
    context.send(201);
}).authorize(function(context) {
    return (context.getHeader("api-key") in apiKeys.admin);
});
```

<div id="route_onunauthorized"><h3>onUauthorized(<i>callback</i>)</h3></div>

This method allows you to configure a route-level response to requests that fail the route-specific authorization handler, if present. A route-level onUnauthorized handler will override the global onUnauthorized handler set by Rocky’s [*onUnauthorized()*](#rocky_onunauthorized) method for requests made to the specified route.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to authorize or reject the request |

The callback function receives a [Rocky.Context](#context) object as its single argument and will be executed for all unauthorized requests made to the specified route.

#### Return Value ####

Nothing.

#### Example ####

```squirrel
// Delete a user
app.on("delete", "/users/([^/]*)", function(context) {
    // Grab the username from the regex
    local username = context.matches[1];

    delete users[username];
    context.send(201);
}).authorize(function(context) {
    return (context.getHeader("api-key") in apiKeys.admin);
}).onUnauthorized(function(context) {
    context.send(401, { "message": "API-Key does not have delete permissions for the users resource." });
});
```

<div id="route_ontimeout"><h3>onTimeout(<i>callback</i>)</h3></div>

This method allows you to configure a route-level response to requests that exceed the timeout. A route-level onTimeout handler will override the global onTimeout handler set by Rocky’s [*onTimeout()*](#rocky_ontimeout) method for requests made to the specified route.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to manage requests that timed out |

The callback takes a [Rocky.Context](#context) object as its single argument and will be executed for all timed out requests made to the specified route. The callback should (but is not required to) send a response code of 408.

#### Returns ####

Nothing.

#### Example ####

```squirrel
app.get("/", function(context) {
    device.send("getTemp", context.id);
}).onTimeout(function(context) {
    context.send(408, { "message": "Device timeout fetching temp data"});
});

device.on("getTempResponse", function(data) {
    local context = Rocky.getContext(data.id);
    if (!context.isComplete()) {
        context.send(200, { "temp": data.temp });
    }
});
```

<div id="route_onexception"><h3>onException(<i>callback</i>)</h3></div>

This method allows you to configure a route-level response handler for requests that encounter runtime errors. A route-level onException handler will override the global onException handler set by Rocky’s [*onTimeout()*](#rocky_ontimeout) method for requests made to the specified route.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to manage requests that triggered runtime errors |

The callback takes a [Rocky.Context](#context) object and the exception as its arguments. See the example below for usage guidance. It will be executed for all requests made to the specified route that encounter runtime errors. This method should (but is not required to) send a response code of 500.

#### Returns ####

Nothing.

#### Example ####

```squirrel
app.get("/", function(context) {
    x = 5;  // Throws an error
    context.send(200, { "data": x });
}).onException(function(context, ex) {
    context.send(500, { "message": "Agent Error", "error": ex });
});
```

<div id="route_hashandler"><h3>hasHandler(<i>handlerName</i>)</h3></div>

This method allows you to check whether a specific handler has been set for a given [Rocky.Route](#route) instance.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *handlerName* | String | Yes | The requested handler’s name |

#### Returns ####

Boolean &mdash; `true` if the named handler has been registered, otherwise `false`.

<div id="route_gethandler"><h3>getHandler(<i>handlerName</i>)</h3></div>

This method allows you to retrieve a specific handler by its name.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *handlerName* | String | Yes | The requested handler’s name |

#### Returns ####

Function &mdash; The named handler, otherwise `null`.

<div id="route_execute"><h3>execute(<i>handlerName</i>)</h3></div>

<div id="route_gettimeout"><h3>getTimeout()</h3></div>

This method allows you to retrieve the current route-specific timeout setting.

#### Returns ####

Float &mdash; The current timeout value.

<div id="route_settimeout"><h3>setTimeout(<i>timeout</i>)</h3></div>

This method allows you to specify a new route-level timeout setting.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *timeout* | Float or integer | Yes | The new timeout setting |

#### Returns ####

Float &mdash; The new timeout value.

<div id="context"><h2>Rocky.Context Instance Methods</h2></div>

A Rocky.Context object encapsulates an [HTTP Request Table](https://developer.electricimp.com/api/httprequest), an [HTTPResponse](https://developer.electricimp.com/api/httpresponse) object, and other important information. When a request is made, Rocky will automatically generate a new context object for that request and pass it to the required callbacks. Never manually create a Rocky.Context object.

<div id="context_send"><h3>send(<i>statuscode[, message]</i>)</h3></div>

This method returns a response to a request made to a Rocky application.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *statuscode* | Integer | Yes | The response’s [HTTP status code](http://en.wikipedia.org/wiki/List_of_HTTP_status_codes) |
| *message* | String, array or table | No | The response’s body. Arrays and tables are automatically JSON-encoded before being sent |

#### Return Value ####

Boolean &mdash; `false` if the context has already been used to respond to the request, otherwise `true`.

#### Examples ####

```squirrel
app.get("/color", function(context) {
    context.send(200, { "color": led.color })
})
```

<h3>send(<i>message</i>)</h3>

The *send()* method may also be invoked without a status code. When invoked in this fashion, a status code of 200 is assumed.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | String, array or table | Yes | The response’s body. Arrays and tables are automatically JSON-encoded before being sent |

#### Return Value ####

Boolean &mdash; `false` if the context has already been used to respond to the request, otherwise `true`.

#### Example #####

```squirrel
app.get("/", function(context) {
    context.send("OK");  // Equivalent to context.send(200, "OK");
})
```

<div id="context_iscomplete"><h3>isComplete()</h3></div>

This method indicates whether or not a response has been sent for the current context. Rocky keeps track of whether or not a response has been sent, and middlewares and route handlers don’t execute if the context has already sent a response.

This method should primarily be used for developers extending Rocky.

#### Return Value ####

Boolean &mdash; `true` if the context’s response has already been sent, otherwise `false`.

<div id="context_getheader"><h3>getHeader(<i>name</i>)</h3></div>

This method attempts to retrieve a header from the context’s [HTTP Request table](https://developer.electricimp.com/api/httprequest).

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | The header’s name |

#### Return Value ####

String &mdash; If the header is present, the value of the header; otherwise `null`.

#### Example ####

```squirrel
// user:password
auth <- "Basic 55de9ca4317bcee87146df33d308ca2d";

app.get("/", function(context) {
    context.send(200, "OK");
}).authorize(function(context) {
    return (context.getHeader("Authorization") == auth);
});
```

<div id="context_setheader"><h3>setHeader(<i>name, value</i>)</h3></div>

This method adds the specified header to the [HTTPResponse](https://developer.electricimp.com/api/httpresponse) object sent by calling [*send()*](#context_send).

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *name* | String | Yes | The header’s name |
| *value* | String | Yes | The header’s value |

#### Return Value ####

Nothing.

#### Example ####

```squirrel
app.get("/", function(context) {
    // Redirect requests made to / to /index.html
    // Add a `location` header
    context.setHeader("Location", http.agenturl() + "/index.html");
    context.send(301);
});
```

<div id="context_settimeout"><h3>setTimeout(<i>timeout[, callback][, exceptionHandler]</i>)</h3></div>

This method allows you to specify a timeout for the context. Calling this method immediately sets a timer which will fire when the timeout is exceeded. This sets a time limit before which the context must be resolved by calling [*send()*](#context_send).

If the timer fires and no function has been passed into *callback*, then the context will be sent with a status code of 504 (gateway timeout).

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *timeout* | Float or integer | Yes | The new timeout setting |
| *callback* | Function | No | A handler to be called if the timeout is exceeded |
| *exceptionHandler* | Function | No | A handler to be called if the callback triggers a runtime error |

#### Returns ####

Nothing.

<div id="context_isbrowser"><h3>isBrowser()</h3></div>

This method indicates whether the `Accept: text/html` header was present.

#### Return Value ####

Boolean &mdash; `true` if the `Accept: text/html` header was present; otherwise `false`.

#### Example ####

```squirrel
const INDEX_HTML = @"
<html>
    <head>
        <title>My Agent</title>
    </head>
    <body>
        <h1>Hello World!</h1>
    </body>
</html>
";

app.get("/", function(context) {
    context.send(200, { message = "Hello World!" });
});

app.get("/index.html", function(context) {
    if (!context.isBrowser()) {
        // If it was an API request
        context.setHeader("location", http.agenturl());
        context.send(301);
        return;
    }

    // If it was a browser request:
    context.send(200, INDEX_HTML);
});
```

## Rocky.Context Class Methods ##

<div id="context_get"><h3>Rocky.Context.get(<i>id</i>)</h3></div>

This method allows you to retrieve a specific context as referenced by its unique ID.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *id* | String | Yes | The ID of the required context |

#### Returns ####

[Rocky.Context](#context) &mdash; the requested context object, or `null` if the ID is unrecognized.

<div id="context_sendtoall"><h3>Rocky.Context.sendToAll(<i>statuscode, response[, headers]</i>)</h3></div>

This method sends a response to **all** open requests. The preferred way of invoking this method is by calling Rocky’s [*sendToAll()*](#rocky_sendtoall) method.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *statuscode* | Integer | Yes | The response’s [HTTP status code](http://en.wikipedia.org/wiki/List_of_HTTP_status_codes) |
| *response* | String | Yes | The response’s body |
| *headers* | Table | No | Additional response headers and their values. Default: no extra headers |

#### Returns ####

Nothing.

## Rocky.Context Properties ##

<div id="context_req"><h3>context.req</h3></div>

The *req* property is a representation of the underlying [HTTP Request table](https://developer.electricimp.com/api/httprequest). All fields available in the HTTP Request table can be accessed through this property.

If a `content-type` header was included in the request, and the content type was set to `application/json` or `application/x-www-form-urlencoded`, the *body* property of the request will be a table representing the parsed data, rather than the raw body.

If the content type was set to `multipart/form-data;`, the *body* property will be an array of tables.

**Note 1** If the application requires access to the raw and *unparsed* body of the request, this can be accessed at *context.req.rawbody*.

**Note 2** If you make the *http.post()* call without any HTTP headers explicitly specified, you may end up receiving a request with the `application/x-www-form-urlencoded` content type.

#### Examples ####

In the following example, we assume requests made to POST */users* include a `content-type` header:

```squirrel
app.post("/users", function(context) {
    local username = null;
    local user = {
        "name": null,
        "twitter": null
    }

    if (!("username" in context.req.body)) {
        context.send(400, { "message": "Missing Required Parameter 'username'" });
        return;
    }

    username = context.req.body.username;

    if (username in users) {
        context.send(400, { "message": format("Username '%s' already taken.", username) });
        return;
    }

    if ("name" in context.req.body) user.name = context.req.body.name;
    if ("twitter" in context.req.body) user.twitter = context.req.body.twitter;

    users[username] <- user;

    /******************** SET THE LOCATION HEADER ********************/
    context.setHeader("location", format("/users/%s", username));

    context.send(201);
});
```

The following examples show the difference between *context.req.body* and *context.req.rawbody*. First, code to send a post request:

```squirrel
// Note that application/x-www-form-urlencoded content-type is added to headers by default
local req = http.post( (http.agenturl() + "/data"), {}, "hello world" )
    req.sendasync(function(res) {
    server.log(res.statuscode);
})
```

Now, a way to get the parsed request body as a table:

```squirrel
app.post("/data", function(context) {
    // In this case table identifier will be printed in the server log
    server.log(context.req.body);
    context.send(200);
});
```

And a way to get the unparsed request body as a string:

```squirrel
app.post("/data", function(context) {
    // In this case string "hello world" will be printed in the server log
    server.log(context.req.rawbody);
    context.send(200);
});
```

<div id="context_id"><h3>context.id</h3></div>

The *id* property is a unique value that identifies the context. It is primarily used during long-running tasks and asynchronous requests. See Rocky’s [*getContext()*](#rocky_getcontext) method for an example of its usage.

<div id="context_path"><h3>context.path</h3></div>

The *path* property is an array that contains each element in the path. If a request is made to `/a/b/c` then *path* will be `["a", "b", "c"]`.

#### Example ####

```squirrel
app.get("/users/([^/]*)", function(context) {
    // Grab the username from the path
    local username = context.path[1];

    // if the user doesn't exist:
    if (!(username in users)) {
        context.send(404, { "message": format("No 'user' resource matching '%s'", username) });
        return;
    }

    // Return the user if it exists
    context.send(200, users[username]);
});
```

<div id="context_matches"><h3>context.matches</h3></div>

The *matches* property is an array that represents the results of the regular expression used to find a matching route. If you included a regular expression in your [signature](#signatures), you can use the *matches* array to access any expressions you may have captured. The first element of the array will always be the full path.

#### Example ####

```squirrel
app.get("/users/([^/]*)", function(context) {
    // Grab the username from the regular expression matches, instead of the path array
    local username = context.matches[1];

    // if the user doesn't exist:
    if (!(username in users)) {
        context.send(404, { "message": format("No 'user' resource matching '%s'", username) });
        return;
    }

    // Return the user if it exists
    context.send(200, users[username]);
});
```

<div id="context_userdata"><h3>context.userdata</h3></div>

The *userdata* property can be used by the developer to store any information relevant to the current context. This is primarily used during long-running tasks and asynchronous requests.

#### Example ####

```squirrel
app.get("/temp", function(context) {
    context.userdata = { "startTime": time() };
    device.send("getTemp", context.id);
});

device.on("getTempResponse", function(data) {
    local context = app.getContext(data.id);
    local roundTripTime = time() - context.userdata.startTime;
    context.send(200, { "temp": data.temp, "requestTime": roundTripTime });
});
```

<div id="context_sent"><h3>context.sent</h3></div>

The *sent* property is **deprecated**. Developers should instead call [*isComplete()*](#context_iscomplete).

<div id="signatures"><h2>Signatures</h2></div>

Signatures can either be fully qualified paths (`/led/state`) or include regular expressions (`/users/([^/]*)`). If the path is specified using a regular expression, any matches will be added to the [Rocky.Context](#context) object passed into the callback.

In the following example, we capture the desired user’s username:

```squirrel
app.get("/users/([^/]*)", function(context) {
    // Grab the username from the regex
    // (context.matches[0] will always be the full path)
    local username = context.matches[1];

    if (username in usersTable) {
        // If we found the user, return the user object
        context.send(usersTable[username]);
    } else {
        // If the user doesn't exist, return a 404
        context.send(404, { "error": "Unknown User" });
    }
});
```

<div id="middleware"><h2>Middleware</h2></div>

Middleware allows you to add new functionality to your request handlers easily and scalably. Middleware functions can be attached at either a global level through Rocky’s [*use()*](#rocky_use) method, or at the route level with [*Rocky.Route.use()*](#route_use). Middleware functions are invoked before the main request handler and can aid in debugging, data validation and transformation, and more.

Middleware functions are invoked with two parameters: a [Rocky.Context](#context) object and a reference, *next*, to the next middleware/handler in the chain (see [**Order of Execution**](#middleware_orderofexecution), below). At the end of the middleware, always call this reference as a function to ensure the next middleware is executed. If there is no subsequent middleware, the call to *next* hands control back to Rocky.

Responding to a request in a middleware prevents further middleware functions and event handlers (such as *authorize*, *onAuthorized*, etc) from executing.

In the following example, we create a middleware, *debuggingMiddleware()* that logs debug information for all incoming requests:

```squirrel
// Middleware to add some debugging information:
function debuggingMiddleware(context, next) {
    server.log("Got a request!");
    server.log("   VERB: " + context.req.method.toupper());
    server.log("   PATH: " + context.req.path.tolower());
    server.log("   TIME: " + time());

    // Invoke the next middleware in the sequence
    next();
}

app <- Rocky.init();
app.use(debuggingMiddleware);

app.get("/", function(context) {
    context.send({ "message": "Hello World!" });
});

app.get("/data", function(context) {
    context.send(data);
});
```

Middleware functions can also be used to extend or override default event handlers. In the following example we create middleware functions for checking whether read and write requests are authorized, and another middleware for validating write data:

```squirrel
// Middleware to check if incoming request has access to read data
function readAuthMiddleware(context, next) {
    local apiKey = context.getHeader("API-KEY");

    // Send a response will prevent the route handler from executing
    if (apiKey == null || !(apiKey in readKeys)) { context.send(401, { "error": "UNAUTHORIZED" }); }

    // Invoke the next middleware
    next();
}

// Middleware to check if incoming request has access to write data
function writeAuthMiddleware(context, next) {
    local apiKey = context.getHeader("API-KEY");

    // Send a response will prevent the route handler from executing
    if (apiKey == null || !(apiKey in writeKeys)) { context.send(401, { "error": "UNAUTHORIZED" }); }

    // Invoke the next middleware
    next();
}

// Middleware to validate incoming data
function validateDataMiddleware(context, next) {
    // If required parameters are missing, send a response (which prevents the route handler from executing)
    if (!("lowTemp" in context.req.body)) { context.send(400, { "error": "Missing required parameter 'lowTemp'" }); }
    if (!("highTemp" in context.req.body)) { context.send(400, { "error": "Missing required parameter 'highTemp'" }); }

    // Invoke the next middleware
    next();
}

app <- Rocky.init();

// Requests to GET /data will execute readAuthMiddleware,
// then the route handler if the readAuthMiddle didn't respond
app.get("/data", function(context) {
      context.send(200, data);
}).use([ readAuthMiddleware ]);

// Requests to POST /data will execute writeAuthMiddleware,
// then validateDataMiddleware, then the route handler if both
// middlewares didn't respond
app.post("/data", function(context) {
    // By the time we get here, we know we're authorized and have the
    // data we're expecting!

    // Send the data down to the device
    device.send("data", context.req.body);

    context.send({ "message": "Success!" });
}).use([writeAuthMiddleware, validateDataMiddleware]);
```

Having access to the function referenced by *next* allows you to complete asynchronous operations before moving on to the next middleware or handler. In the following example, we look up a user ID from a remote service before moving on:

```squirrel
function userIdMiddleware(context, next) {
    if (!("username" in context.req.body)) {
        context.send(400, { "error": "Missing required parameter 'username'" });
        next();
    } else {
        local username = context.req.body.username;
        userService.getUserId(username, function(err, resp, result) {
            if (err != null) {
                context.send(400, { "error": err });
            } else {
                // stash the results in context.userdata for later use
                local userId = result.userId;
                context.userdata["username"] <- username;
                context.userdata["userId"] <- result.userId;
            }
            next();
        });
    }
}

app.get("/user", function(context) {
    local userId = context.userdata.userId;
    context.send(users[userId]);
}).use([ userIdMiddleware ]);
```

<div id="middleware_orderofexecution"><h3>Order of Execution</h3></div>

When Rocky processes an incoming HTTPS request, the following sequence of events takes place:

- Rocky adds the access control headers unless the `accessControl` setting (see [*rocky.init()*](#rocky_init)) is set to `false`.
- Rocky rejects non-HTTPS requests unless the `allowUnsecure` setting (see [*rocky.init()*](#rocky_init)) is set to `true`.
- Rocky parses the request body.
    - Rocky sends a 400 response if there was an error parsing the data.
- Global-level middleware functions are invoked.
- Route-level middleware functions are invoked.
- If present, the global authorization function is invoked.
    - If the global authorization function returned `true`, the global request handler is invoked.
    - If the global authorization function returned `false`, the [global unauthorized handler](#rocky_onunauthorized) is invoked.

If a middleware function sends a response, no further action will be taken on the request.

If a runtime errors occurs after the data has been parsed, the *onError* handler will be invoked.

<div id="cors_requests"><h2>CORS Requests</h2></div>

During a cross domain AJAX request, some browsers will send a [preflight request](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing#Preflight_example) to determine if it has the permissions needed to perform the action.

To accommodate preflight requests you can add a wildcard `OPTIONS` handler:

```squirrel
app.on("OPTIONS", ".*", function(context) {
    context.send("OK");
});
```

By default, Rocky automatically adds the following headers to all responses:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept
Access-Control-Allow-Methods: POST, PUT, GET, OPTIONS
```

If you wish to override these default headers, you can instantiate Rocky with the `accessControl` setting set to `false`, and use a middleware to add the headers you wish to include. For example:

```squirrel
function customCORSMiddleware(context, next) {
    context.setHeader("Access-Control-Allow-Origin", "*");
    context.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, X-Version");
    context.setHeader("Access-Control-Allow-Methods", "POST, PUT, PATCH, GET, OPTIONS");

    // invoke the next middleware
    next();
}

app <- Rocky.init({ "accessControl": false });
app.use([ customCORSMiddleware ]);
```

## License ##

This library is licensed under [MIT License](./LICENSE).
