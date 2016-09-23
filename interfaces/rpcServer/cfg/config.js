var config = {};

config.LOGGER = {};
config.LOGGER.name = 'rpcServer';
config.LOGGER.infoFile = './log/rpcServerInfo.log';
config.LOGGER.debugFile = './log/rpcServerDebug.log';
config.LOGGER.errorFile = './log/rpcServerError.log';

config.FILE = {};
config.FILE.options = {
    flags: 'w',
    defaultEncoding: 'utf8',
    fd: null,
    mode: 0666,
    autoClose: true
};
config.FILE.defaultCaptureFile = './log/capture.txt';

//config.USER = {};
//config.USER.DUZ = 60;
//
//config.FACILITY = {};
//config.FACILITY.ID = 2957;

// rpc server socket
config.rpcServer = {};
config.rpcServer.port = 9010;

// mvdm socket
config.mvdmClient = {};
config.mvdmClient.host = '10.2.100.110';
config.mvdmClient.port = 9020;

config.client = {};
config.client.defaultName = "CPRS";

config.workerQ = {}
config.workerQ.size = 1;

try {
    module.exports = config;
}
catch(exception) {
    //will fail in browser - config is referenced by browser client for convenience
}

