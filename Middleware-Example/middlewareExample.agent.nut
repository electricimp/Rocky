#require "rocky.class.nut:1.3.0"

// Dummy Data for API
data <- { "foo": "bar" };

// Middleware to log debug information to device logs
function debugMiddleware(context, next) {
    // Log some information
    server.log("Got an incoming HTTPS Request:");
    server.log("   TIME: " + time());
    server.log("   VERB: " + context.req.method.toupper());
    server.log("   PATH: " + context.req.path.tolower());

    // Call next to indicate that we're done with this middleware
    next();
}

// Middleware to add CORS headers
function CORSMiddleware(context, next) {
    server.log("Adding CORS headers to request")

    // Add some headers
    context.setHeader("Access-Control-Allow-Origin", "*");
    context.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, X-Version");
    context.setHeader("Access-Control-Allow-Methods", "POST, PUT, PATCH, GET, OPTIONS");

    // invoke the next middleware
    next();
}

// Setup Rocky and use the debugMiddleware on ALL requests
app <- Rocky().use([ debugMiddleware ]);

// GET / - send hello world
app.get("/", function(context) {
    context.send({ "Message": "Hello World!" });
});

// GET /data - send our dummy data
app.get("/data", function(context) {
    context.send(data);
}).use([ CORSMiddleware ]);
