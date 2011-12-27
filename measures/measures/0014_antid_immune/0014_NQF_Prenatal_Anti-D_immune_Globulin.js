function() {
  var patient = this;
  var measure = patient.measures["0014"];
  if (measure == null)
    measure={};

  <%= init_js_frameworks %>

  var day = 24 * 60 * 60;
  var year = 365 * day;
  var effective_date =  <%= effective_date %>;
  var earliest_encounter = effective_date - year;
  var estimated_conception = null;
  var estimated_dates_of_conception = normalize(measure.estimated_date_of_conception_patient_characteristic);
  if (estimated_dates_of_conception.length > 0) {
    estimated_conception = _.max(measure.estimated_date_of_conception_patient_characteristic);
  }
  var delivery_date = maxInRange(measure.delivery_live_births_procedure_procedure_performed, earliest_encounter, effective_date);

  var population = function() {
    var live_birth_diagnosis = inRange(measure.delivery_live_births_diagnosis_diagnosis_active,
                                       earliest_encounter,
                                       effective_date);
    return live_birth_diagnosis && delivery_date;
  }

  var denominator = function() {
    if (!estimated_conception) {
      return false;
    }
    var prenatal_encounter = inRange(measure.prenatal_visit_encounter, estimated_conception, effective_date);
    var drh_neg_diagnosis = lessThan(measure.d_rh_negative_diagnosis_active, effective_date);
    var primigravida = inRange(measure.primigravida_diagnosis_active, earliest_encounter, effective_date);
    var multigravida = inRange(measure.multigravida_diagnosis_active, earliest_encounter, effective_date);
    var rh_status_mother = minValueInDateRange(measure.rh_status_mother_laboratory_test_result, earliest_encounter, delivery_date, false)
    var rh_status_baby = minValueInDateRange(measure.rh_status_baby_laboratory_test_result, earliest_encounter, delivery_date, false)
    return (prenatal_encounter && (
      drh_neg_diagnosis ||
      (primigravida && !rh_status_mother) ||
      (multigravida && !rh_status_mother && !rh_status_baby)));
  }

  var numerator = function() {
    var estimated_conception_within_ten_months = actionFollowingSomething(estimated_conception, delivery_date, (304 * day));
    var antid_admin_between_26_30_weeks = inRange(measure.anti_d_immune_globulin_medication_administered,
                                                  estimated_conception + (26 * 7 * day),
                                                  estimated_conception + (30 * 7 * day));
    return (estimated_conception_within_ten_months && antid_admin_between_26_30_weeks);
  }

  var exclusion = function() {
    var medical_reason = inRange(measure.medical_reason_medication_not_done, earliest_encounter, effective_date);
    var patient_reason = inRange(measure.patient_reason_medication_not_done, earliest_encounter, effective_date);
    var system_reason = inRange(measure.system_reason_medication_not_done, earliest_encounter, effective_date);
    var antid_declined_between_26_and_30_weeks = inRange(measure.anti_d_immune_globulin_declined_medication_not_done,
                                                         estimated_conception + (26 * 7 * day),
                                                         estimated_conception + (30 * 7 * day));
    return (antid_declined_between_26_and_30_weeks|| system_reason || medical_reason || patient_reason);
  }

  map(patient, population, denominator, numerator, exclusion);
};
