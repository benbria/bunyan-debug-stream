const bunyan = require('bunyan');
const { expect } = require('chai');
const streamToString = require('stream-to-string');
const through2 = require('through2');
const BunyanDebugStream = require('../src/BunyanDebugStream');
const { dateToString } = require('../src/utils');

const ENTRY = {
    level: bunyan.INFO,
    msg: "Hello World",
    name: 'proc',
    pid: 19,
    time: new Date(1534347616844)
};


function generateLogEntry(entry, options={}) {
    const out = through2();
    const bunyanDebugStreamOptions = Object.assign({
        colors: null,
        out
    }, options);

    const stream = new BunyanDebugStream(bunyanDebugStreamOptions);
    stream.write(entry);
    stream.end();
    out.end();

    return streamToString(out);
}

describe('BunyanDebugStream', function() {
    it('should generate a log entry', function() {
        return generateLogEntry(ENTRY)
        .then(result => {
            expect(result).to.equal(`${dateToString(ENTRY.time)} proc[19] INFO:  Hello World\n`);
        });
    });

    it('should use a custom date format', function() {
        return generateLogEntry(ENTRY, {showDate: time => time.toISOString()})
        .then(result => {
            expect(result).to.equal(`2018-08-15T15:40:16.844Z proc[19] INFO:  Hello World\n`);
        });
    });

});