'use strict';

const nodem = require('nodem');
const parameterService = require('./parameterService');
const RPCRunner = require('./rpcRunner').RPCRunner;
const _ = require('lodash');

process.env.gtmroutines = `${process.env.gtmroutines} .`;
const db = new nodem.Gtm();
const DEBUG = true;
db.open();

parameterService.setDB(db);
parameterService.setDebug(DEBUG);
parameterService.printDebug('starting db');

process.on('uncaughtException', (err) => {
    db.close();
    console.log(err);
    parameterService.printDebug('Uncaught Exception:\n', err);
    process.exit(1);
});

process.on('exit', () => {
    parameterService.printDebug('exiting db');
});

// Initialize the user via RPC Runner - assuming 62 is ALEXANDER,ROBERT
const rpcRunner = new RPCRunner(db);
rpcRunner.initializeUser(62);

const parameterList = [{
    type: 'add',
    description: 'add user template for ALEXANDER,ROBERT',
    parameterName: 'GMV USER DEFAULTS',
    entity: 'USR',
    instance: 'DefaultTemplate',
    value: '00;DIC(4.2,|DAILY VITALS',
}];

const createAvailableOptions = function createAvailableOptions(parameter) {
    const availableOptions = ['entity', 'instance'];
    let options = {};
    _.each(availableOptions, (option) => {
        if (parameter[option]) {
            options = _.extend(options, {
                [option]: parameter[option],
            });
        }
    });
    return options;
};

_.each(parameterList, (parameter) => {
    switch (parameter.type) {
        case 'add':
        case 'update':
        case 'addChangeDelete':
            console.log(`running ${parameter.type} with parameter ${parameter.parameterName}`);
            parameterService[parameter.type](parameter.parameterName, parameter.value,
                createAvailableOptions(parameter));
            break;
        case 'get':
            console.log(`running ${parameter.type} with parameter ${parameter.parameterName}`);
            console.log(`result => ${parameterService.get(parameter.parameterName, createAvailableOptions(parameter))}`);
            break;
        default:
            console.log('invalid type');
    }
});

parameterService.printDebug('db close');
db.close();
