/*global define*/
define([
   'jquery',
   'underscore',
   'backbone',
   'handlebars',
   'mvdmEvents/eventModel',
   'mvdmEvents/mvdmEventCollection',
   'management/managementModel',
   'jsBeautify',
   'text!mvdmEvents/mvdmEvents.hbs',
   'text!mvdmEvents/eventModal.hbs',
   'config',
   'bootstrap',
   'mvdmEvents/templateHelpers'
], function ($, _, Backbone, Handlebars, MVDMEventModel, MVDMEventCollection, ManagementModel, jsBeautify, MVDMEventsTemplate, EventModalTemplate) {
   'use strict';

   var MVDMEventsView = Backbone.View.extend({

      template: Handlebars.compile(MVDMEventsTemplate),

      initialize: function () {

         // Open MVDM event web sockets
         this.mvdmEventsSocket = new WebSocket("ws://" + config.admin.host + ":" + config.admin.port);

         this.mvdmEventsSocket.onopen = function () {
            // Web Socket is connected, send data using send()
            console.log("WebSocket: MVDM Event Handler is connected...");
         };

         this.mvdmEventsSocket.onmessage = _.bind(function (eventMsg) {
            this.handleMvdmEvent(eventMsg);

         }, this);

         this.mvdmEventsSocket.onclose = function () {
            // websocket is closed.
            console.log("WebSocket: MVDM Event Handler connection is closed...");
         };

         this.eventFilter = '';

         this.management = new ManagementModel();

         this.management.on('change', _.bind(function() {
            this.render();
         }, this));

         this.management.fetch();

         this.eventModalTemplate = Handlebars.compile(EventModalTemplate);
      },

      events: {
         "change .filter-select": 'onFilterChange',
         'click .clear-events-list': 'onClearEventsList',
         'click .mvdm-event-row': 'onEventShow'
      },

      render: function () {

         var collection = MVDMEventCollection;

         if (this.eventFilter) {
            collection = MVDMEventCollection.filterByType(this.eventFilter);
         }

         this.$el.html(this.template({
            mvdmEvents: collection.toJSON(),
            eventFilter: this.eventFilter,
            management:this.management.toJSON()
         }));
         return this;
      },

      handleMvdmEvent: function (eventMsg) {
         var event = JSON.parse(eventMsg.data);

         MVDMEventCollection.push(new MVDMEventModel(event.data));

         this.render();
      },

      onFilterChange: function(e) {
         var filterVal = e.currentTarget.value;
         if (filterVal.toLowerCase() === 'all') {
            this.eventFilter = '';
         }
         else {
            this.eventFilter = e.currentTarget.value;
         }

         this.render();
      },

      onClearEventsList: function(e) {
         e.preventDefault();

         //clear events
         MVDMEventCollection.reset();

         this.render();
      },

      //display event details modal
      onEventShow: function(e) {
         if (!e.currentTarget.dataset.cid) {
            return;
         }

         var mvdmEvent = MVDMEventCollection.get(e.currentTarget.dataset.cid);

         var modalHtml = this.eventModalTemplate({
            eventData: jsBeautify.js_beautify(
               JSON.stringify(
                  _.omit(mvdmEvent.toJSON(), 'cid')
               ))
         });

         this.$el.find('#mvdm-event-modal-container').html(modalHtml);

         var modelEl = this.$el.find('#mvdm-event-modal');

         modelEl.find('.modal-title-type').html(mvdmEvent.get('type'));

         modelEl.modal('show');
      },

      onClose: function () {
         this.mvdmEventsSocket.close();
      }
   });


   return MVDMEventsView;
});