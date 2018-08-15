[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)

Output stream for Bunyan which prints human readable logs.

[![NPM](https://nodei.co/npm/bunyan-debug-stream.png?downloads=true&downloadRank=true&stars=true)](https://nodei.co/npm/bunyan-debug-stream/)

What is it?
===========

BunyanDebugStream is a stream for [Bunyan](https://github.com/trentm/node-bunyan) which takes in
Bunyan logs and outputs human readable log lines (which look sort of vaguely like syslog output.)

There are plenty of other npm packages out there that do something similar, but this is the best
one. ;)

![](https://github.com/benbria/bunyan-debug-stream/blob/master/docs/sample.png)

Features
========

* Colored output based on log level.
* Concise and pretty stack traces using [exception-formatter](https://github.com/benbria/exception-formatter).
* A [morgan](https://www.npmjs.org/package/morgan) inspired custom formatter for request/response
  objects.  Will automatically fetch response time out of `res.responseTime` or `duration`
  (from [bunyan-middleware](https://github.com/tellnes/bunyan-middleware)) or
  `response-time` (from [express-bunyan-logger](https://github.com/villadora/express-bunyan-logger).)
* Easy to customize output of different fields.

Installation
============

    npm install --save-dev bunyan-debug-stream

Usage
=====

The most basic usage involves just creating a Bunyan logger which writes raw objects to the stream:

    var bunyanDebugStream = require('bunyan-debug-stream');

    var log = bunyan.createLogger({
        name: "myLog",
        streams: [{
            level:  'info',
            type:   'raw',
            stream: bunyanDebugStream({
                basepath: __dirname, // this should be the root folder of your project.
                forceColor: true
            })
        }],
        serializers: bunyanDebugStream.serializers
    });

This will get you up and running with 90% of the functionality you probably want, but there are lots
of ways you can customize the behavior of bunyan-debug-stream.  Note you can also use the Bunyan
`stdSerializers` - the `bunyanDebugStream.serializers` are the same as `stdSerializers`, but add
a few custom fields.

Options
=======

### basepath and basepathReplacement

`basepath` should be the root folder of your project.  This is used in two ways; if you turn on
`src: true` in your Bunyan logger, then instead of printing filenames like
'/users/me/myprojects/project/src/file.js', your logger will strip the `basepath` and instead print
'./s/file.js'.  (Note that we also shorten folder names to keep log lines short.)  This same value
also gets passed on to [exception-formatter](https://github.com/benbria/exception-formatter).  If
you don't specify a value, this will default to `process.cwd()`.

`basepathReplacement` defaults to './' - this is what we replace the `basepath` with.

### colors

If you don't like the default color scheme, you can easily change it.  Bunyan-debug-stream uses
the [colors](https://github.com/Marak/colors.js) module to color lines.  Pass in something like:

    bunyanDebugStream({
        colors: {
            'info': 'blue',
            'error': ['red', 'bold']
        }
    })

### forceColor

By default, colors are disabled when outputting to a non-tty.  If you're having problems getting colors to work in
grunt or gulp, set this to true.  Note that under the hood, this sets `colors.enabled` to true (see
[colors.js#102](https://github.com/Marak/colors.js/issues/102)) so this may affect other modules that use `colors`.

### stringifiers and prefixers

Bunyan logs can contain extra data beyond just the log message.  If you call:

    log.info({foo: {bar: "baz"}}, "Hello World");

Then bunyan-debug-stream might print something like:

    Nov 27 09:50:04 MyLogger[649] INFO:  main (./s/app:195): Hello World
      foo: {"bar": "baz"}

Sometimes you might want to have more specific control over how certain objects are printed.
This is where `stringifiers` and `prefixers` come in.

`options.stringifiers` is a hash where keys are object names and values are functions which return
a string.  So, for example, you might do:

    bunyanDebugStream({
        stringifiers: {
            'foo': function(foo) {return "The value of bar is " + foo.bar;}
        }
    })

This would change the output to be:

    Nov 27 09:50:04 MyLogger[649] INFO:  main (./s/app:195): Hello World
      foo: The value of bar is baz

Specifying a stringifier of `null` will prevent a value from being displayed at all.

Usually you can do what you want with a simple stringifier which takes a single parameter and
returns a string, but for those extra special complicated cases, you can do something like:

    bunyanDebugStream({
        stringifiers: {
            'req': function(req, options) {
                return {
                    value: req.url + " - " + options.entry.res.statusCode,
                    consumed: ["req", "res"]
                }
            }
        }
    })

`options` here will be a `{entry, useColor, debugStream}` object, where `entry` is the full Bunyan
log entry, `useColor` is true if output is in color and false otherwise, and `debugStream` is the
BunyanDebugStream object.  This will let you combine  multiple properties into a single line.  This
will also prevent the "res" property from being shown.  (Note if you don't like the way we write out
requests, you can do exactly this.)

For short objects that you include in many logs, such as user names or host names, you might
not want to print them on a line by themselves.  `prefixers` work just like `stringifiers`, except
the value will be prefixed at the beginning of the message:

    bunyanDebugStream({
        prefixers: {
            'foo': function(foo) {return foo.bar;}
        }
    })

would result in the output:

    Nov 27 09:50:04 MyLogger[649] INFO:  main (./s/app:195): [baz] Hello World

### showProcess and processName

By default bunyan-debug-stream will show the logger name and the PID of the current process.
If `options.showProcess` is true, bunyan-debug-stream will also show the process name.
This defaults to the second argument in `process.argv` (minus the path and the extension)
on the assumption that you're running with `node myApp.js`, but you can override this by passing
an explicit `options.processName`.

### showDate

Turned on by default.
If `options.showDate` is false, bunyan-debug-stream doesn't print timestamps in the output, e.g.:

```
    MyLogger[649] INFO:  main (./s/app:195): [baz] Hello World
```

### showPid

Turned on by default.
If `options.showPid` is false, bunyan-debug-stream doesn't print the process ID in the output, e.g.:

```
    Nov 27 09:50:04 MyLogger INFO:  main (./s/app:195): [baz] Hello World
```

### showLoggerName

Turned on by default.
If `options.showLoggerName` is false, bunyan-debug-stream doesn't print `name` property of the logger in the output, e.g.:

```
    Nov 27 09:50:04 [649] INFO:  main (./s/app:195): [baz] Hello World
```

### showLevel

Turned on by default.
If `options.showLevel` is false, bunyan-debug-stream doesn't print the log level (e.g. INFO, DEBUG) in the output, e.g.:

```
    Nov 27 09:50:04 MyLogger[649]  main (./s/app:195): [baz] Hello World
```

### showMetadata

Turned on by default.
If `options.showMetadata` is false, bunyan-debug-stream doesn't print arbitrary properties of passed
metadata objects (also known as extra fields) to the log. However, this option does not apply to properties
that have specific prefixer or stringifier handlers.  
For example, if you have `foo` stringifier and arbitrary field `extraField: 1`, like below:

```
    const log = bunyanDebugStream({
        stringifiers: {
            'foo': function(foo) {return "The value of bar is " + foo.bar;}
        }
    });

    log.info({extraField: 1, foo: {bar: "baz"}}, "Hello World");
```

Then you can expect that `extraField` will get omitted, and only `foo` will be printed:

```
    Nov 27 09:50:04 MyLogger[649] INFO:  main (./s/app:195): Hello World
      foo: The value of bar is baz
```

### maxExceptionLines

If present, `options.maxExceptionLines` is passed along to exception-formatter as
`options.maxLines`.  This controls the maximum number of lines to print in a stack trace.  0
for unlimited (the default.)

### out

`options.out` is the stream to write data to.  Must have a `.write()` method.

Special Handling for Requests
=============================

If the object you pass has a `req` field, then bunyan-debug-stream will automatically turn this
into a log line (somewhat inspired by the `morgan` logger's 'dev' mode.)  To get the most out of
this, you should pass `req` and `res` and use the default bunyan serializers (or use our custom
serializers.)  If you don't pass a message to the logger, then the request line will replace the
message.

bunyan-debug-stream tries to play nice with [bunyan-middleware](https://github.com/tellnes/bunyan-middleware)
and [express-bunyan-logger](https://github.com/villadora/express-bunyan-logger).

bunyan-debug-stream will read the following values from the following locations.  `entry` is the log
entry passed in to `bunyan-debug-stream`.  Where multiple locations are listed, bunyan-debug-stream
will try to fetch the value in the order specified.

* `statusCode` - From `res.statusCode` or from `entry['status-code']` (express-bunyan-logger.)
* `user` - bunyan-debug-stream will look for a `req.user` or a `entry.user` object.  In either case
  it will user `user.username`, `user.name`, or `user.toString()`.
* `responseTime` - `res.responseTime`, `entry.duration` (bunyan-middleware), or
  `entry['response-time']` (express-bunyan-logger.)
* `contentLength` - `res.headers['content-length']` or `entry['res-headers']['content-length']`
  (express-bunyan-logger.)
* `host` - `req.headers.host`
* `url` - `req.url`
* `method` - `req.method`

Note that `user`, `contentLength`, and `responseTime` will not show up if you are using the
standard Bunyan serializers.

Special Handling for Errors
===========================

By default, errors are processed using [exception-formatter](https://github.com/benbria/exception-formatter).
If you don't like the way exception-formatter works, you can specify your own `serializer` for `err`
to print them however you like.  :)
