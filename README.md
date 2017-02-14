# Rocky 2.0.0

Rocky is an framework for building powerful and scalable APIs for your imp-powered products. The Rocky library consists of the following classes:

- [Rocky](#rocky) - The core application - used to create routes, set default handlers, etc.
  - [Rocky.get](#rocky_verb) - Creates a handler for GET requests that match the specified signature.
  - [Rocky.put](#rocky_verb) - Creates a handler for PUT requests that match the specified signature.
  - [Rocky.post](#rocky_verb) - Creates a handler for POST requests that match the specified signature.
  - [Rocky.on](#rocky_on) - Creates a handler for requests that match the specified verb and signature.
  - [Rocky.use](#rocky_use) - Binds one or more middlewares to all routes.
  - [Rocky.authorize](#rocky_authorize) - Specify the default ```authorize``` handler for all routes.
  - [Rocky.onUnauthorized](#rocky_onunauthorized) - Specify the default ```onUnauthorized``` callback for all routes.
  - [Rocky.onTimeout](#rocky_ontimeout) - Set the default ```onTimeout``` handler for all routes.
  - [Rocky.onNotFound](#rocky_onnotfound) - Set the default ```onNotFound``` handler for all routes.
  - [Rocky.onException](#rocky_onexception) - Set the default ```onException``` handler for all routes.
  - [Rocky.getContext](#rocky_getcontext) - Static method that retreives a [Rocky.Context](#context) object by it's ID (primairly used for asyncronous requests).
  - [Rocky.sendToAll](#rocky_sendtoall) - Static method that sends a response to *all* open requests/requests.
- [Rocky.Route](#route) - A handler for a specific route.
  - [Rocky.Route.use](#route_use) - Binds one or more middlewares to the route.
  - [Rocky.Route.authorize](#route_authorize) - Specify the default ```authorize``` handler for the route.
  - [Rocky.Route.onUnauthorized](#route_onunauthorized) - Specify the default ```onUnauthorized``` callback for the route.
  - [Rocky.Route.onTimeout](#route_ontimeout) - Set the default ```onTimeout``` handler for the route.
  - [Rocky.Route.onException](#route_onexception) - Set the default ```onException``` handler for the route.
- [Rocky.Context](#context) - The information passed into a route handler.
  - [Rocky.Context.send](#context_send) - Sends an HTTP response.
  - [Rocky.Context.isComplete](#context_iscomplete) - Returns whether a response has been sent for the current context.
  - [Rocky.Context.getHeader](#context_getheader) - Attempts to get the specified header from the request object.
  - [Rocky.Context.setHeader](#context_setheader) - Sets the specified header in the response object.
  - [Rocky.Context.req](#context_req) - The HTTP Request Table.
  - [Rocky.Context.id](#context_id) - Context's unique ID.
  - [Rocky.Context.userdata](#context_userdata) - Field developers can use to store data during long running tasks, etc
  - [Rocky.Context.path](#context_path) - The full path the request was made to.
  - [Rocky.Context.matches](#context_matches) - An array of matches to the path's regular expression.
  - [Rocky.Context.isBrowser](#context_isbrowser) - Returns true if the request contains an ```Accept: text/html``` header.
  - [Rocky.Context.sendToAll](#context_sendtoall) - Static method that sends a response to *all* open requests/contexts.
- [Middleware](#middleware) - Used to transform and verify data before the main request handler.
  - [Order of Execution](#middleware_orderofexecution) - Explanation of the execution flow for middleware and event handlers.
- [CORS Requests](#cors_requests) - How to handle cross-site HTTP requests ([CORS](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing)).

<div id="rocky"><h2>Rocky(*[options]*)</h2></div>

Calling the Rocky constructor creates a new Rocky application. An optional *options* table can be passed into the constructor to override default behaviours:

```squirrel
#require "rocky.class.nut:2.0.0"

app <- Rocky()
```

### options

An table containing any of the following keys may be passed into the Rocky constructor to modify the default behaviour:

- *accessControl* &mdash; Modifies whether or not Rocky will automatically add `Access-Control` headers to the response object
- *allowUnsecure* &mdash; Modifies whether or not Rocky will accept HTTP requests (as opposed to HTTPS)
- *strictRouting* &mdash; Enables or disables strict routing. By default, Rocky will consider `/foo` and `/foo/` as identical paths.
- *timeout* &mdash; Modifies how long Rocky will hold onto a request before automatically executing the *onTimeout* handler

These are the default settings:

```squirrel
defaults <- {
    accessControl = true,
    allowUnsecure = false,
    strictRouting = false,
    timeout = 10
}
```

<div id="rocky_verb"><h3><em>VERB</em>(*signature, callback[, timeout]*)</h3></div>
The **VERB** methods allow you to assign routes based on the specified verb and signature. The following **VERB**s are allowed:

- app.get(*signature, callback[, timeout]*)
- app.put(*signature, callback[, timeout]*)
- app.post(*signature, callback[, timeout]*)

When a match is found on the verb (as specified by the method) and the *signature*, the callback function will be executed. The callback takes a [Rocky.Context](#context) object as a parameter. An optional route-level timeout can be passed in. If no timeout is passed in, the timeout set in the constructor will be used.

```squirrel
// responds with ```200, { "message": "hello world "}```
// when the user makes a GET request to the agent URL:
app.get("/", function(context) {
    context.send({ message = "hello world" })
})
```

<div id="signatures"><h3>Signatures</h3></div>

Signatures can either be fully qualified paths (`/led/state`) or include regular expressions (`/users/([^/]*)`). If the path is specified using a regular expressions, any matches will be added to the [Rocky.Context](#context) object passed into the callback. In the following example, we capture the desired user’s username:

```squirrel
// Get a user
app.get("/users/([^/]*)", function(context) {
    // grab the username from the regex
    // (context.matches[0] will always be the full path)
    local username = context.matches[1];

    if (username in usersTable) {
        // if we found the user, return the user object
        context.send(usersTable[username]);
    } else {
        // if the user doesn't exist, return a 404
        context.send(404, { error = "Unknown User" });
    }
});
```

<div id="rocky_on"><h3>on(*verb, signature, callback[, timeout]*)</h3></div>

The *on()* method allows you to create APIs that use verbs other than GET, PUT or POST. The *on()* method works identically to the **.VERB** methods, but we specify the verb as a string:

```squirrel
// Delete a user
app.on("delete", "/users/([^/]*)", function(context) {
    // grab the username from the regex
    // (context.matches[0] will always be the full path)
    local username = context.matches[1];

    if (username in usersTable) {
        // if we found the user,
        // delete it, and return 201
        delete usersTable[username]
        context.send(201, null);
    } else {
        // if the user doesn't exist, return a 404
        context.send(404, { error = "Unknown User" });
    }
});
```

<div id="rocky_use"><h3>use(*callback*)</h3></div>

The *use()* method allows you to attach a middleware, or array of middlewares, to the global Rocky object.

```squirrel
// Create a function to add the specific CORS headers we want:
function customCORSMiddleware(context, next) {
    context.setHeader("Access-Control-Allow-Origin", "*");
    context.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    context.setHeader("Access-Control-Allow-Methods", "POST, PUT, PATCH, GET, OPTIONS");

    // invoke the next middleware
    next();
}

app <- Rocky({ "accessControl": false });

// Add the middleware to the global Rocky object so every
// incoming request has the headers added
app.use([ customCORSMiddleware ]);

app.get("/", function(context) {
    context.send(200, { "message": "Hello World" });
});
```

See the [Middleware](#middleware) section for more information.

<div id="rocky_authorize"><h3>authorize(*callback*)</h3></div>

The *authorize()* method allows you to specify a global function to validate or authorize incoming requests. The callback function takes a [Rocky.Context](#context) object as a parameter, and must return either `true` (if the request is authorized) or `false` (if the request is not authorized).

The *authorize()* method is executed before the main request handler.

- If the callback return `true`, the route handler will be invoked.
- If the callback returns `false`, the [onUnauthorized](#rocky_onAuthorized) response handler is invoked.

```squirrel
app.authorize(function(context) {
    // ensure user has a valid api key
    return (context.getHeader("api-key") in apiKeys);
});
```

<div id="rocky_onunauthorized"><h3>onUauthorized(*callback*)</h3></div>

The *onUnauthorized()* method allows you to configure the default response to requests that fail the *authorize()* method. The callback method takes a [Rocky.Context](#context) object as a parameter. The callback method passed into *onUnauthorized()* will be executed for all unauthorized requests that do not have a route-level [onUnauthorized](route_onUnauthorized) response handler.

```squirrel
app.onUnauthorized(function(context) {
    context.send(401, { message = "Unauthorized" });
});
```

<div id="rocky_ontimeout"><h3>onTimeout(*callback*)</h3></div>

The *onTimeout()* method allows you to configure the default response to requests that exceed the timeout. The callback method passed into *onTimeout()* will be executed for all timed out requests that do not have a route-level [onTimeout](route_onTimeout) response handler. The callback method takes a [Rocky.Context](#context) object as a parameter. This method should (but is not required to) send a response code of 408.

```squirrel
app.onTimeout(function(context) {
    context.send(408, { message = "Agent Timeout" });
});
```

<div id="rocky_onnotfound"><h3>onNotFound(*callback*)</h3></div>

The *onNotFound()* method allows you to configure the response handler for requests that could not match a route. The callback method takes a [Rocky.Context](#context) object as a parameter. This method should (but is not required to) send a response code of 404.

```squirrel
app.onNotFound(function(context) {
    context.send(404, { message = "Oh snaps, the resource you're looking for doesn't exist!" });
});
```

<div id="rocky_onexception"><h3>onException(*callback*)</h3></div>

The *onException()* method allows you to configure the global response handler for requests that encounter runtime errors. The callback method takes two parameters: a [Rocky.Context](#context) object and the exception. The callback method will be excuted for all requests that encounter runtime errors and do not have a route-level [onException](route_onexception) handler. This method should (but is not required to) send a response code of 500.

```squirrel
app.onException(function(context, ex) {
    context.send(500, { message = "Internal Agent Error", error = ex });
});
```

<div id="rocky_getcontext"><h3>Rocky.getContext(id)</h3></div>

Every [Rocky.Context](#context) object created by Rocky is assigned a unique ID that can found using [context.id](#context_id). We can use this ID and the static *getContext()* method to retreive previously created contexts. This is primarily used for long-running or asyncronous requests. In the following example, we fetch the temperature from the device when the request is made:

```squirrel
app.get("/temp", function(context) {
    // send a getTemp request to the device, and pass context.id as the data
    device.send("getTemp", context.id);
});

device.on("getTempResponse", function(data) {
    // when we get a getTempResponse message, get the context
    local context = Rocky.getContext(data.id);

    // then send the response using that context
    if (!context.isComplete()) {
        context.send(200, { temp = data.temp });
    }
});
```

```squirrel
// device code
agent.on("getTemp", function(id) {
    local temp = getTemp();
    // when we get a "getTemp" message, send back a response that includes
    // the id passed to the device, and the temperature data
    agent.send("getTempResponse", { id = id, temp = temp });
});
```

<div id="rocky_sendtoall"><h3>Rocky.sendToAll(*statuscode, response[, headers]*)</h3></div>

The static *sendToAll()* method sends a response to **all** open requests. This is most useful in APIs that allow for long-polling.

```squirrel
app.get("/poll", function(context) {
    // do nothing
});

// when we get data - send it to all open requests
device.on("data", function(data) {
    Rocky.sendToAll(200, data);
});
```

<div id="route"><h2>Rocky.Route</h2></div>

The Rocky.Route object encapsulates the behaviour associated with a request made to a specific route. You should never call the Rocky.Route constructor directly, instead, you should create and associate routes using the [*Rocky.get()*](#rocky_get), [*Rocky.put()*](#rocky_put), [*Rocky.post()*](rocky_post) and [*Rocky.on()*](rocky_on) methods.

All methods that affect the behaviour of a route are designed to be used in a fluent style, ie. the methods return the route object itself, so they can be chained together.

```squirrel
app.get("/", function(context) {
    context.send({ message = "hello world" });
}).authorize(function(context) {
    return (context.getHeader("api-key") in apiKeys);
}).onUnauthorized(function(context) {
    context.send(401, { message = "Unauthorized" });
});
```

<div id="route_use"><h3>use(*callback*)</h3></div>

The *use()* method allows you to attach a middleware, or array of middlewares, to a specific route.

```squirrel
app <- Rocky();

// Custom Middleware to validate new users
function validateNewUserMiddleware(context, next) {
    // Make sure they supplied a username nas password
    if (!("username" in context.req.body)) context.send(400, "Required parameter 'username' missing");
    if (!("passwordHash" in context.req.body)) context.send(400, "Required parameter 'passwordHash' missing");

    // Ensure the username is unique
    if (context.req.body.username in usernames) context.send(400, "Requested username already exists");

    // invoke the next middleware
    next();
}

app.post("/users", function(context) {
    // We know the required fields exist because we've attached a middleware
    // to check for them
    usernames[context.req.body.username] <- context.req.body.passwordHash;
    context.send(200, "OK");
}).use([ validateNewUserMiddleware ]);
```

See the [Middleware](#middleware) section for more information.

<div id="route_authorize"><h3>authorize(*callback*)</h3></div>

The *authorize()* method allows you to specify a route-level function to validate or authorize incoming requests. A route-level authorize handler will override the global authorize handler set by [*Rocky.authorize()*](#rocky_authorize) for requests made to the specified route. The callback function takes a [Rocky.Context](#context) object as a parameter, and must return either `true` (if the request is authorized) or `false` (if the request is not authorized).

The *authorize()* method is executed before the main request handler.

- If the callback returns `true`, the route handler will be invoked.
- If the callback returns `false`, the [onUnauthorized](#rocky_onAuthorized) handler is invoked.

```squirrel
// Delete a user
app.on("delete", "/users/([^/]*)", function(context) {
    // grab the username from the regex
    local username = context.matches[1];

    delete users[username];
    context.send(201);
}).authorize(function(context) {
    return (context.getHeader("api-key") in apiKeys.admin);
});
```

<div id="route_onunauthorized"><h3>onUauthorized(*callback*)</h3></div>

The *onUnauthorized()* method allows you to configure a route -level response to requests that fail the *authorize()* method. A route-level onUnauthorized handler will override the global onUnauthorized handler set by [*Rocky.onUnauthorized()*](#rocky_onunauthorized) for requests made to the specified route. The callback method takes a [Rocky.Context](#context) object as a parameter. The callback method passed into *onUnauthorized()* will be executed for all unauthorized requests that do not have a route-level [onUnauthorized](route_onUnauthorized) response handler.

```squirrel
// Delete a user
app.on("delete", "/users/([^/]*)", function(context) {
    // grab the username from the regex
    local username = context.matches[1];

    delete users[username];
    context.send(201);
}).authorize(function(context) {
    return (context.getHeader("api-key") in apiKeys.admin);
}).onUnauthorized(function(context) {
    context.send(401, { message = "API-Key does not have delete permissions for the users resource." });
});
```

<div id="route_ontimeout"><h3>onTimeout(*callback*)</h3></div>

The *onTimeout()* method allows you to configure a route level response to requests that exceed the timeout. A route-level onTimeout handler will override the global onTimeout handler set by [*Rocky.onTimeout()*](#rocky_ontimeout) for requests made to the specified route. The callback method passed into *onTimeout()* will be executed for all timed out requests that do not have a route-level [onTimeout](route_onTimeout) response handler. The callback method takes a [Rocky.Context](#context) object as a parameter. This method should (but is not required to) send a response code of 408.

```squirrel
app.get("/", function(context) {
    device.send("getTemp", context.id);
}).onTimeout(function(context) {
    context.send(408, { message = "Device timeout fetching temp data"});
});

device.on("getTempResponse", function(data) {
    local context = Rocky.getContext(data.id);
    if (!context.isComplete()) {
        context.send(200, { temp = data.temp });
    }
});
```

<div id="route_onexception"><h3>onException(*callback*)</h3></div>

The *onException()* method allows you to configure a route-level response handler for requests that encounter runtime errors. A route-level onException handler will override the global onException handler set by [*Rocky.onTimeout()*](#rocky_onexception) for requests made to the specified route. The callback method takes two parameters: a [Rocky.Context](#context) object and the exception. The callback method will be excuted for all requests that encounter runtime errors and do not have a route-level [onException](route_onexception) handler. This method should (but is not required to) send a response code of 500.

```squirrel
app.get("/", function(context) {
    x = 5;  // throws an error
    context.send(200, { data = x });
}).onException(function(context, ex) {
    context.send(500, { message = "Agent Error", error = ex });
});
```

<div id="context"><h2>Rocky.Context</h2></div>

The Rocky.Context object encapsulates an [HTTP Request Table](http://electricimp.com/docs/api/httphandler/) an [HTTPResponse](http://electricimp.com/docs/api/httpresponse/) object, and other important information. When a request is made, Rocky will automatically generate a new context object for that request and pass it to the required callbacks, ie. you should never manually create a Rocky.Context object.

<div id="context_send"><h3>send(*statuscode, [message]*)</h3></div>


The *send()* method returns a response to a request made to a Rocky application. It takes two parameters. The first is an integer [HTTP status code](http://en.wikipedia.org/wiki/List_of_HTTP_status_codes). The second parameter, which is optional, is the data that will be relayed back to the requester, either a string, an array of values, or a table.

**Note** Arrays and tables are automatically JSON-encoded before being sent.

The method returns `false` if the context has already been used to respond to the request.

```
app.get("/color", function(context) {
    context.send(200, { color = led.color })
})
```

<h3>send(message)</h3>

The *send()* method may also be invoked without a status code. When invoked in this fashion, a status code of 200 is assumed:

```squirrel
app.get("/", function(context) {
    context.send("OK");  // equivalent to context.send(200, "OK");
})
```

<div id="context_iscomplete"><h3>isComplete()</h3></div>

The *isComplete()* method returns whether or not a response has been sent for the current context. Rocky keeps track of whether or not a response has been sent, and middlewares and route handlers don't execute if the context has already sent a response. This method should primairly be used for developers extending Rocky.

<div id="context_getheader"><h3>getHeader(headerName)</h3></div>

The *getHeader()* method attempts to retreive a header from the HTTP Request table. If the header is present, the value of that header is returned, if the header is not present `null` will be returned.

```squirrel
// user:password
auth <- "Basic 55de9ca4317bcee87146df33d308ca2d";

app.get("/", function(context) {
    context.send(200, "OK");
}).authorize(function(context) {
    return (context.getHeader("Authorization") == auth);
});
```

<div id="context_setheader"><h3>setHeader(headerName, data)</h3></div>

The *setHeader()* method adds the specified header to the HTTPResponse object sent during [context.send](#context_send). In the following example, we create a new user resource and return the location of that resource with a `location` header:

```squirrel
app.get("/", function(context) {
    // redirect requests made to / to /index.html
    context.setHeader("Location", http.agenturl() + "/index.html");
    context.send(301);
});
```

<div id="context_req"><h3>context.req</h3></div>

The *context.req* property is a representation of the HTTP Request table. All fields available in the [HTTP Request Table](http://electricimp.com/docs/api/http/onrequest) can be accessed through this property.

If a `content-type` header was included in the request, and the content type was set to `application/json`, `application/x-www-form-urlencoded` or `multipart/form-data;` the *body* propery of the request will be a table representing the parsed data, rather than the raw body. In the following example, we assume requests made to POST */users* include a `content-type` header:

```squirrel
app.post("/users", function(context) {
    local username = null;
    local user = {
        name = null,
        twitter = null
    }

    if (!("username" in context.req.body)) {
        context.send(400, { message = "Missing Required Parameter 'username'" });
        return;
    }

    username = context.req.body.username;

    if (username in users) {
        context.send(400, { message = format("Username '%s' already taken.", username) });
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

**Note** If the application requires access to the raw and *unparsed* body of the request, it can be accessed with *context.req.rawbody*.

**Note** If you make the *http.post()* call without any HTTP headers explicitly specified, you may end up receiving a request with the `application/x-www-form-urlencoded` content type.

To see the difference between *context.req.body* and *context.req.rawbody*, please take a look at following samples. First, code to send post request:

```squirrel
//Note that application/x-www-form-urlencoded content-type is added to headers by default
local req = http.post( (http.agenturl() + "/data"), {}, "hello world" )
    req.sendasync(function(res) {
    server.log(res.statuscode);
})
```

A way to get parsed request body as a table:

```squirrel

app.post("/data", function(context) {
    //In this case table identifier will be printed in the server log
    server.log(context.req.body);
    context.send(200);
});
```

And a way to get unparsed request body as a string:

```squirrel

app.post("/data", function(context) {
    //In this case string "hello world" will be printed in the server log
    server.log(context.req.rawbody);
    context.send(200);
});
```

<div id="context_id"><h3>context.id</h3></div>

The *id* property is a unique ID that identifies the context. This is primairly used during long-running tasks and asynchronous requests. See [rocky.getContext](#rocky_getcontext) for example usage.

<div id="context_userdata"><h3>context.userdata</h3></div>

The *userdata* property can be used by the developer to store any information relevant to the current context. This is primairly used during long-running tasks and asynchronous requests.

```squirrel
app.get("/temp", function(context) {
    context.userdata = { startTime = time() };
    device.send("getTemp", context.id);
});

device.on("getTempResponse", function(data) {
    local context = app.getContext(data.id);
    local roundTripTime = time() - context.userdata.startTime;
    context.send(200, { temp = data.temp, requestTime = roundTripTime });
});
```

<div id="context_path"><h3>context.path</h3></div>

The *path* property is an array that contains each element in the path. If a request is made to `/a/b/c` then *path* will be `["a", "b", "c"]`.

```squirrel
app.get("/users/([^/]*)", function(context) {
    // grab the username from the path
    local username = context.path[1];

    // if the user doesn't exist:
    if (!(username in users)) {
        context.send(404, { message = format("No 'user' resource matching '%s'", username) });
        return;
    }

    // return the user if it exists
    context.send(200, users[username]);
});
```

<div id="context_matches"><h3>context.matches</h3></div>

The *matches* property is an array that represents the results of the regular expression used to find a matching route. If you included a regular expression in your signature, you can use the matches array to access any expressions you may have captured. The first element of the *matches* array will always be the full path.

```squirrel
app.get("/users/([^/]*)", function(context) {
    // grab the username from the regular expression matches, instead of the path array
    local username = context.matches[1];

    // if the user doesn't exist:
    if (!(username in users)) {
        context.send(404, { message = format("No 'user' resource matching '%s'", username) });
        return;
    }

    // return the user if it exists
    context.send(200, users[username]);
});
```

<div id="context_isbrowser"><h3>context.isbrowser()</h3></div>

The *isbrowser()* method returns true if an `Accept: text/html` header was present.

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
    if(!context.isbrowser()) {
        // if it was an API request
        context.setHeader("location", http.agenturl());
        context.send(301);
        return;
    }

    // if it was a browser request:
    context.send(200, INDEX_HTML);
});
```

**Note** The *isbrowser()* method is all lowercase (as opposed to lowerCamelCase).

<div id="context_sendtoall"><h3>Rocky.Context.sendToAll(*statuscode, response[, headers]*)</h3></div>

The static *sendToAll()* method sends a response to **all** open requests. The prefered way of invoking this method is through [*Rocky.sendToAll()*](#rocky_sendtoall).

<div id="context_sent"><h3>context.sent</h3></div>

The *sent* property is **deprecated**. developers should move to using the [*isComplete()*](#context_iscomplete) method instead.

<div id="middleware"><h2>Middleware</h2></div>

Middleware allows you to easily (and scalably) add new functionality to your request handlers. Middleware functions can be attached at either a global level through [Rocky.use](#rocky_use), or at the route level with [Rocky.Route.use](#route_use). Middleware functions are invoked before the main request handler and can aid in debugging, data validation/transformation, and more!

Middleware functions are invoked with two parameters - a [Rocky.Context](#context) object, and a *next()* method. The *next* method invokes the next middleware / handler in the chain (see [Order of Execution](middleware_orderofexecution)).

Responding to a request in a middleware prevents further middleware functions and event handlers (such as authorize, onAuthorized, etc) from executing.

In the following example, we create a middleware that logs debug information for all incoming requests:

```squirrel
// Middleware to add some debugging information:
function debuggingMiddleware(context, next) {
    server.log("Got a request!");
    server.log("   VERB: " + context.req.method.toupper());
    server.log("   PATH: " + context.req.path.tolower());
    server.log("   TIME: " + time());

    // invoke the next middleware
    next();
}

app <- Rocky();
app.use(debuggingMiddleware);

app.get("/", function(context) {
    context.send({ "message": "Hello World! "});
});

app.get("/data", function(context) {
    context.send(data);
});
```

Middleware functions can also be used to extend / override default event handlers. In the following example we create middleware functions for checking whether read and write requests are authorized, and another middleware for validating write data:

```squirrel
// Middleware to check if incoming request has access to read data
function readAuthMiddleware(context, next) {
    local apiKey = context.getHeader("API-KEY");

    // send a response will prevent the route handler from executing
    if (apiKey == null || !(apiKey in readKeys)) { context.send(401, { "error": "UNAUTHORIZED" }); }

    // invoke the next middleware
    next();
}

// Middleware to check if incoming request has access to write data
function writeAuthMiddleware(context, next) {
    local apiKey = context.getHeader("API-KEY");

    // send a response will prevent the route handler from executing
    if (apiKey == null || !(apiKey in writeKeys)) { context.send(401, { "error": "UNAUTHORIZED" }); }

    // invoke the next middleware
    next();
}

// Middleware to validate incoming data
function validateDataMiddleware(context, next) {
    // If required parameters are missing, send a response (which prevents the route handler from executing)
    if (!("lowTemp" in context.req.body)) { context.send(400, { "error" :"Missing required parameter 'lowTemp'" }); }
    if (!("highTemp" in context.req.body)) { context.send(400, { "error" :"Missing required parameter 'highTemp'" }); }

    // invoke the next middleware
    next();
}

app <- Rocky();

// Requests to GET /data will execute readAuthMiddleware,
// then the route handler if the readAuthMiddle didn't respond
app.get("/data", function(context) {
      context.send(200, data);
}).use([ readAuthMiddleware ]);

// Requests to POST /data will execute writeAuthMiddleware,
// then validateDataMiddleware,  then the route handler if both
// middlewares didn't respond
app.post("/data", function(context) {
    // By the time we get here, we know we're authotized and have the
    // data we're expecting!

    // Send the data down to the device
    device.send("data", context.req.body);

    context.send({ "message": "Success!" });
}).use([ writeAuthMiddleware, validateDataMiddleware ]);
```

The *next* method allows you to complete asynchronous operations before moving on to the next middleware or handler. In the following example, we lookup a userId from a remote service before moving on:

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

When Rocky processes an incoming HTTPS request, the following takes place:

- Rocky adds the access control headers unless the `accessControl` setting is set to false
- Rocky rejects non-HTTPS requests unless the `allowUnsecure` setting is not set to true
- Rocky parsees the body (and send a 400 response if there was an error parsing the data)
- Invoke the Rocky-level middleware functions
- Invoke the Route-level middleware functions
- Invoke the authorize function, and based on the return on authorize:
  - Invokes the request handler (is authorize returned `true`)
  - Invokes the onUnauthorized handler (is authorize returned `false`)

If a middleware function send a response, no further action will be taken on the request.

If a runtime errors occurs after the data has been parsed, the onError handler will be invoked.

<div id="cors_requests"><h2>CORS Requests</h2></div>

During a cross domain AJAX request, some browsers will send a [preflight request](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing#Preflight_example) to determine if it has the permissions needed to perform the action.

To accomodate preflight requests you can add a wildcard OPTIONS handler:

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

If you wish to override the default headers, you can instantiate Rocky with the `accessControl` setting set to `false`, and use a middleware to add the headers you wish to include:

```squirrel
function customCORSMiddleware(context, next) {
    context.setHeader("Access-Control-Allow-Origin", "*");
    context.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, X-Version");
    context.setHeader("Access-Control-Allow-Methods", "POST, PUT, PATCH, GET, OPTIONS");

    // invoke the next middleware
    next();
}

app <- Rocky( { "accessControl": false });
app.use([ customCORSMiddleware ]);
```

## License

Rocky is licensed under [MIT License](https://github.com/electricimp/Rocky/blob/master/LICENSE).
