#!/usr/bin/env node
'use strict';

var express = require('express');
var _ = require('underscore');
var app = express();
var expressWs = require('express-ws')(app);
var bodyParser = require('body-parser');
var moment = require('moment');
var path = require('path');
var CONFIG = require('./cfg/config.js');
var LOGGER = require('./logger.js');
var mvdmManagement = require('./mvdmManagement');
var EventManager = require('./eventManager');

function init() {
   // parse application/x-www-form-urlencoded
   app.use(bodyParser.urlencoded({ extended: false }));

   // parse application/json
   app.use(bodyParser.json());


   //default path goes to index.html
   app.get('/', function(req, res){
      res.sendFile(path.join(__dirname + '/static/index.html'));
   });

   //get management settings
   app.get('/management', function(req, res) {
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify(mvdmManagement));
   });

   //update management settings
   app.put('/management', function(req, res) {
      if (!req.body) {
         return res.sendStatus(400);
      }

      var settings = req.body;

      if (_.has(settings, 'isMvdmEmulated')) {
         mvdmManagement.isMvdmEmulated = settings.isMvdmEmulated;
      }

      if (_.has(settings, 'isNodeOnly')) {
         mvdmManagement.isNodeOnly = settings.isNodeOnly;
      }


      return res.sendStatus(200);
   });

   var mvdmClients = [];

   //mvdm events socket
   app.ws('/mvdmEvents', function(ws, req) {
      mvdmClients.push(ws);

      ws.on('close', function(){
         handleSocketClose(ws, mvdmClients);
      });

   });

   var rpcClients = [];

   //rpc events socket
   app.ws('/rpcEvents', function(ws, req) {

      rpcClients.push(ws);

      ws.on('close', function(){
         handleSocketClose(ws, rpcClients);
      });
   });

   initMVDMEventListeners(mvdmClients);
   initRPCEventListeners(rpcClients);

   var port = CONFIG.mvdmClient.port;
   app.listen(port, function () {
      LOGGER.info('MVDM Client listening on port ' + port);
   });

   //static files
   app.use(express.static(__dirname + "/static")); //use static files in ROOT/public folder
   app.use(express.static(__dirname + "/node_modules")); //expose node_modules for bootstrap, jquery, underscore, etc.
   app.use(express.static(__dirname + "/cfg")); //config - exposing for convenience
}

function handleSocketClose(ws, clients) {
   for(var i = 0; clients.length; i++) {
      if (clients[i] === ws) {
         clients.splice(i, 1);
         break;
      }
   }
}

function initMVDMEventListeners(mvdmClients) {
   //handle socket request
   EventManager.on('mvdmCreate', function(event) {
      processEvent(mvdmClients, 'MVDM', event);
   });

   EventManager.on('mvdmDescribe', function(event) {
      processEvent(mvdmClients, 'MVDM', event);
   });

   EventManager.on('mvdmList', function(event) {
      processEvent(mvdmClients, 'MVDM', event);
   });

   EventManager.on('mvdmUpdate', function(event) {
      processEvent(mvdmClients, 'MVDM', event);
   });

   EventManager.on('mvdmRemove', function(event) {
      processEvent(mvdmClients, 'MVDM', event);
   });

   EventManager.on('mvdmUnremoved', function(event) {
      processEvent(mvdmClients, 'MVDM', event);
   });

   EventManager.on('mvdmDelete', function(event) {
      processEvent(mvdmClients, 'MVDM', event);
   });
}

function initRPCEventListeners(rpcClients) {
   EventManager.on('rpcCall', function(event) {
      processEvent(rpcClients, 'RPC', event);
   });
}

function processEvent(clients, eventCategory, event) {

   var resObj = {
      type: 'socketMessage_' + eventCategory,
      eventCategory: eventCategory,
      data: event
   };

   //broadcast event to clients
   _.forEach(clients, function (client) {
      client.send(JSON.stringify(resObj));
   });
}

module.exports.init = init;

