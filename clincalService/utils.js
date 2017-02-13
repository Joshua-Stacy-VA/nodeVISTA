#!/usr/bin/env node

'use strict';

function toContext(req) {
    return {
        userId: req.auth.userId,
        facilityId: req.auth.facilityId,
        patientId: req.patientId
    };
}

module.exports = {
    toContext: toContext
};
