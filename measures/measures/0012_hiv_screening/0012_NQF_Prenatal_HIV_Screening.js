function() {
  var patient = this;
  var measure = patient.measures["0012"];
  if (measure == null)
    measure={};

  <%= init_js_frameworks %>

  var day = 24*60*60;
  var year = 365 * day;
  var effective_date =  <%= effective_date %>;
  var earliest_encounter = effective_date - year;
  var conception = normalize(measure.estimated_date_of_conception_patient_characteristic);
  var estimated_conception = null;

  var population = function() {
    var live_birth_diagnosis = inRange(measure.delivery_live_births_diagnosis_diagnosis_active, earliest_encounter, effective_date);
    var live_birth_procedure = inRange(measure.delivery_live_births_procedure_procedure_performed, earliest_encounter, effective_date);
    return live_birth_diagnosis && live_birth_procedure;
  }

  var denominator = function() {
    if (conception.length==0)
      return false;
    estimated_conception = _.max(conception);
    return inRange(measure.prenatal_visit_encounter, estimated_conception, effective_date);
  }

  var numerator = function() {
    var estimated_conception_within_ten_months = actionFollowingSomething(estimated_conception, measure.delivery_live_births_procedure_procedure_performed, 304*day);
    var encounters_in_range = _.sortBy(selectWithinRange(measure.prenatal_visit_encounter, estimated_conception, effective_date), function(num){ return num; });  // there has to be at least 1 due to denominator
    var first_encounter = encounters_in_range[0];
    var hiv_screen_after_first = actionFollowingSomething(first_encounter, measure.hiv_screening_laboratory_test_performed, 30*day);
    var hiv_screen_after_second = false;
    if(encounters_in_range.length > 1) {
      var second_encounter = encounters_in_range[1];
      hiv_screen_after_second = actionFollowingSomething(second_encounter, measure.hiv_screening_laboratory_test_performed, 30*day);
    }
    return estimated_conception_within_ten_months && (hiv_screen_after_first || hiv_screen_after_second);
  }

  var exclusion = function() {
    var hiv_prior_to_encounter = actionFollowingSomething(measure.hiv_diagnosis_active, measure.prenatal_visit_encounter, year) +
                                 actionFollowingSomething(measure.hiv_diagnosis_inactive, measure.prenatal_visit_encounter, year);
    var medical_reason = inRange(measure.medical_reason_laboratory_test_not_done, earliest_encounter, effective_date);
    var patient_reason = inRange(measure.patient_reason_laboratory_test_not_done, earliest_encounter, effective_date);
    return hiv_prior_to_encounter || medical_reason || patient_reason;
  }

  map(patient, population, denominator, numerator, exclusion);
};
