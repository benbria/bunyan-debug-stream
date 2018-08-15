const bunyan = require('bunyan');
const { expect } = require('chai');
const streamToString = require('stream-to-string');
const through2 = require('through2');
const BunyanDebugStream = require('../src/BunyanDebugStream');
const { dateToString } = require('../src/utils');

function generateLogEntry(entry) {
    const out = through2();
    const bunyanDebugStreamOptions = {
        colors: null,
        out
    };

    const stream = new BunyanDebugStream(bunyanDebugStreamOptions);
    stream.write(entry);
    stream.end();
    out.end();

    return streamToString(out);
}

describe('BunyanDebugStream', function() {
    it('should generate a log entry', function() {
        const now = new Date();

        const entry = {
            level: bunyan.INFO,
            msg: "Hello World",
            name: 'proc',
            pid: 19,
            time: now
        };

        return generateLogEntry(entry)
        .then(result => {
            expect(result).to.equal(`${dateToString(now)} proc[19] INFO:  Hello World\n`);
        });
    });
});