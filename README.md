# Rocky Framework

Rocky is a [Squirrel](http://squirrel-lang.org) framework aimed at simplifying the process of building powerful APIs in your [Electric Imp](http://electricimp.com) agent. It allows you to specify callback handlers for specific routes (verb + path), for events such as unhandled errors, and do some other useful things like build authentication and timeouts into your API. Think of it a bit like Node’s [Express](http://expressjs.com), only for Squirrel.

## Usage

### Constructor

Instantiate a Rocky application:

```squirrel
app <- Rocky()

app.get("/", function(context) {
	context.send("Hello World!")
})
```

## Application

### Settings

The following settings can be passed into Rocky to alter how it behaves:

- ```timeout``` Modifies how long Rocky will hold onto a request before automatically executing the *onTimeout* handler
- ```allowUnsecure``` Modifies whether or not Rocky will accept HTTP requests (as opposed to HTTPS)
- ```strictRouting``` Enables or disables strict routing &ndash; by default Rocky will consider `/foo` and `/foo/` as identical paths
- ```accessControl``` Modifies whether or not Rocky will automatically add Access-Control headers to the response object.

The default settings are listed below:

```squirrel
{
	timeout = 10,
	allowUnsecure = false,
	strictRouting = false,
	accessControl = true
}
```

### Class Methods

## VERB(*path*, *callback*)

The ```VERB``` methods provide the basic routing functionality in Rocky. The following verbs are available: GET, PUT and POST.

The following snippet illustrates the simplest route handler possible.

```squirrel
app.get("/", function(context) {
	context.send("Hello World")
})
```

Regular expressions may also be used in the path. If you wanted to respond to both `/color` and `/colour` you could create the following handler:

```squirrel
app.get("/colo[u]?r", function(context) {
	context.send(200, { color = led.color })
})
```

## License

Rocky is licensed under [MIT License](./LICENSE).
