#!/usr/bin/env node

'use strict';

const _ = require('underscore');
const moment = require('moment');

const AbstractService = require('../abstractService');

/**
 * Vitals Service Class
 *
 */
class VitalsService extends AbstractService {

    /**
     * Vitals Service constructor.
     *
     * @param {Object} db VistA database instance.
     * @param {Object} serviceContext Contains service context data.
     * @param {String} serviceContext.userId User identifier.
     * @param {String} serviceContext.facilityId Facility identifier.
     * @param {String} serviceContext.patientId Patient identifier.
     */
    constructor(db, serviceContext) {
        if (!serviceContext.patientId) {
            throw new Error('Vitals service requires a patientId');
        }

        super(db, serviceContext);

        //private methods

        this.emitEvent = function(eventName, data) {
            this._emitEvent(eventName, 'Vital', data);
        };
    }

    /**
     * Creates a new vital.
     *
     * @param {Object} args Create vital arguments.
     * @param {String} args.vitalsTakenDateTime Vitals taken date time.
     * @param {String} args.vitalType Vital type identifier.
     * @param {String} args.hospitalLocation Hospital location identifier.
     * @param {String} args.value Vital value.
     * @param {String} args.units Units value.
     * @param {String=} args.enteredBy Entered by identifier. Defaults to user.
     * @param {String=} args.vitalsEnteredDateTime Vitals entered date time. Defaults to T.
     * @param {String=} args.supplementalO2 Supplemental O2.
     * @param {Array=} args.qualifiers List of qualifier identifiers.
     * @fires create Service create event.
     * @returns MVDM create response.
     */
    create(args) {

        let mvdmObj = _.pick(args, 'value', 'supplementalO2');

        mvdmObj.type = 'Vital';

        mvdmObj = this.toPointer(
            mvdmObj,
            args,
            'vitalType',
            'hospitalLocation',
            'enteredBy');

        mvdmObj = this.toDateTime(
            mvdmObj,
            args,
            'vitalsTakenDateTime',
            'vitalsEnteredDateTime');

        if (args.qualifiers) {

            mvdmObj.qualifier = [];

            args.qualifiers.forEach(function (qualifer) {
                mvdmObj.qualifier.push({
                    id: qualifer
                });
            });
        }

        let res = this.MVDM.create(mvdmObj);

        this.emitEvent('create', res);

        return res;
    }

    /**
     * Describes a vital.
     *
     * @param {String} vitalId Vital identifier.
     * @fires describe Service describe event.
     * @returns MVDM vital response.
     */
    describe(vitalId) {
        let res = this.MVDM.describe(vitalId);

        this.emitEvent('describe', res);

        return res;
    };

    /**
     * List vital results.
     *
     * If no start and stop dates are indicated, all vitals are returned.
     *
     * If no start date is passed then the start date is set to a time before records were collected.
     *
     * If no end date is passed then the start date is also the end date and if there's no start date, then end date is the current date time.
     *
     * @param {Date=} startDate Start date object.
     * @param {Date=} endDate End date object.
     * @param {Boolean=} suppressEvent Suppress service list event. Defaults to false.
     * @fires list Service list event.
     * @returns {Object} Filtered MVDM list results.
     */
    list(startDate, endDate, suppressEvent) {
        let results =  this.MVDM.list('Vital', this.context.patientId).results;

        //filter results
        if (!endDate && !startDate) {
            endDate = moment().toDate(); //current date time
        }

        if (!startDate) {
            startDate = moment('1900-01-01T00:00:00').toDate(); //by default push date out to before records were collected
        }

        if (!endDate) {
            endDate = startDate;
        }

        let vitals = [];
        results.forEach(function(vital){
            let vitalTakenDateTime = moment(vital.vitalsTakenDateTime.value).toDate();
            if (vitalTakenDateTime >= startDate && vitalTakenDateTime <= endDate) {
                vitals.push(vital);
            }
        });

        let res = {results: vitals};

        if (!suppressEvent) {
            this.emitEvent('list', res);
        }

        return res;
    };

    /**
     * List of most recent vitals within start and stop date/times.
     *
     * If no start and stop dates are indicated, the most recent are returned.
     *
     * If no start date is passed then the start date is set to a time before records were collected.
     *
     * If no end date is passed then the start date is also the end date and if there's no start date, then end date is the current date time.
     *
     * @param {Date=} startDate Start date object.
     * @param {Date=} endDate End date object.
     * @fires mostRecentVitals Service mostRecentVitals event.
     * @returns {Object} Most recent vitals.
     */
    getMostRecentVitals(startDate, endDate) {

        let vitals = this.list(startDate, endDate, true).results;

        //grab most recent
        let mostRecentByType = {};
        vitals.forEach(function(vital) {
            let type = vital.vitalType.label;

            if (!mostRecentByType[type] || moment(vital.vitalsTakenDateTime.value).toDate() >=
                moment(mostRecentByType[type].vitalsTakenDateTime.value).toDate()) {
                //record or overwrite most recent vital by type
                mostRecentByType[type] = vital;
            }
        });

        let mostRecentList = [];
        Object.keys(mostRecentByType).forEach(function(vitalType) {
            mostRecentList.push(mostRecentByType[vitalType]);
        });

        let res = {results: mostRecentList};

        this.emitEvent('mostRecentVitals', res);

        return res;
    };

    /**
     * Removes a vital and marks it as entered in error.
     *
     * @param {String} vitalId Vital identifier.
     * @param {String} reason Reason for removal. Possible values: INCORRECT DATE/TIME, INCORRECT READING, INCORRECT PATIENT, INVALID RECORD
     * @fires remove Service remove event.
     * @returns {Object} MVDM remove result.
     */
    remove(vitalId, reason) {

        let res = this.MVDM.remove(vitalId, reason);

        this.emitEvent('remove', res);

        return res;
    };
}

module.exports = VitalsService;