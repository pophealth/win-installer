// Common functions for variants of 0033 chlamydia screening.
//
// lib/qme/mongo_helpers.rb executes this function on a database
// connection.
function () {
  var root = this;
  
  var day = 24*60*60;

  root.chlamydiaDenominator = function(measure, pregnancy_tests, earliest_encounter, effective_date) {
    // events bounded by measurement period
    var indicative_procedure = inRange(measure.procedures_indicative_of_sexually_active_woman_procedure_performed, earliest_encounter, effective_date);

    // events prior to end of measurement period (could be before measurement period)
    var indicative_labs = lessThan(measure.laboratory_tests_indicative_of_sexually_active_women_laboratory_test_performed,  effective_date);
    var outpatient_encounter = lessThan(measure.encounter_outpatient_encounter, effective_date);
    var iud = lessThan(measure.iud_use_device_applied, earliest_encounter, effective_date);
    var education = lessThan(measure.contraceptive_use_education_communication_to_patient, effective_date);
    var contraceptives = lessThan(measure.contraceptives_medication_active, effective_date);
    var pregnancy_encounter = lessThan(measure.encounter_pregnancy_encounter, effective_date);
    var active = lessThan(measure.sexually_active_woman_diagnosis_active, effective_date);
    
    return (outpatient_encounter && 
           (indicative_procedure || pregnancy_tests.length>0 || iud || education || contraceptives || pregnancy_encounter || indicative_labs || active));
  };

  root.chlamydiaExclusion = function(measure, pregnancy_tests, earliest_encounter, effective_date) {
    var pregnancyTestsInMeasureRange = selectWithinRange(pregnancy_tests, earliest_encounter, effective_date);
   
    var retinoid = actionFollowingSomething(pregnancyTestsInMeasureRange, measure.retinoid_medication_active, 7*day) +
                   actionFollowingSomething(pregnancyTestsInMeasureRange, measure.retinoid_medication_order, 7*day) +
                   actionFollowingSomething(pregnancyTestsInMeasureRange, measure.retinoid_medication_dispensed, 7*day);

    var x_ray = actionFollowingSomething(pregnancyTestsInMeasureRange, measure.x_ray_study_diagnostic_study_performed, 7*day);
    return retinoid || x_ray;
  }
  
}