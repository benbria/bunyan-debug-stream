var bunyan = require('bunyan');
var bunyanDebugStream = require('../lib/BunyanDebugStream');

var log = bunyan.createLogger({
    name: "myLog",
    streams: [{
        level:  'trace',
        type:   'raw',
        stream: bunyanDebugStream({
            basepath: __dirname, // this should be the root folder of your project.
            prefixers: {
                account: function(account) {return account.name;}
            },
            stringifiers: {
                qux: function(qux) {return "The value of bar is " + qux.bar;}
            }
        }),
    }],
    serializers: bunyanDebugStream.serializers
});

function main() {
    log.trace("This is a trace log");
    log.debug("This is a debug log");
    log.info("This is an info log");
    log.warn("This is an warning");
    log.error("This is an error");
    log.fatal("This is a fatal!");
    log.info({account: {name: 'benbria', _id: 12}}, "Example with a prefixer");
    log.info({foo: {bar: "baz"}}, "An example with an object");
    log.info({qux: {bar: "baz"}}, "An example with a stringifier");
    log.error(new Error("Ohs noes!"), "An example with an Error");

    log.info("Some samples with requests");
    log.info({
        req: {
            method: 'GET',
            url: '/foo/index.html',
            headers: {
                host: 'myserver.com'
            }
        },
        res: {
            statusCode: 200,
            _headers: {
                'content-length': 4526
            },
            responseTime: 23
        }
    })

    log.info({
        req: {
            method: 'GET',
            url: '/foo/index.html',
            headers: {
                host: 'myserver.com'

            }
        },
        res: {
            statusCode: 404,
            _headers: {
                'content-length': 4526
            },
            responseTime: 23
        },
        user: "jwalton"
    })

    log.info({
        req: {
            method: 'GET',
            url: '/foo/index.html',
            headers: {
                host: 'myserver.com'

            }
        },
        user: "jwalton"
    }, "A request with a message (and without a response)")
}

main();