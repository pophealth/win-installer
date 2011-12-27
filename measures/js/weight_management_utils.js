// Adds weight management utility functions to the root JS object. These are then
// available for use by the supporting map-reduce functions for any measure
// that needs common definitions of these algorithms.
// lib/qme/mongo_helpers.rb executes this function on a database
// connection.
function() {

  var root = this;
  var year = 365*24*60*60;

  root.weight_denominator = function(measure, period_start, effective_date) {
    var encounter =           inRange(measure.encounter_outpatient_w_pcp_obgyn_encounter, period_start, effective_date);
    var pregnant =            inRange(measure.pregnancy_diagnosis_active,                 period_start, effective_date);
    var pregnancy_encounter = inRange(measure.encounter_pregnancy_encounter,              period_start, effective_date);
    return encounter && !(pregnant || pregnancy_encounter);
  }

  root.weight_population = function(patient, earliest_birthdate, latest_birthdate) {
    return inRange(patient.birthdate, earliest_birthdate, latest_birthdate);
  }
  
  // measure 0421 functions
  
  root.weight_numerator = function(measure, minBMI, maxBMI) {
    encounters = normalize(measure.encounter_outpatient_encounter);
    exam_findings = normalize(measure.bmi_physical_exam_finding);
    followup_plans = normalize(measure.follow_up_plan_bmi_management_care_plan);
    dietary_consult = normalize(measure.dietary_consultation_order_communication_provider_to_provider);
    for(var i=0;i<encounters.length;i++) {
      // for each encounter date
      var encounter_date = encounters[i];
      var earliest_bmi = encounter_date - year/2;
      for (var j=0;j<exam_findings.length;j++) {
        // look for BMI measurements <=6 months before current encounter
        var bmi = exam_findings[j];
        if (inRange(bmi.date, earliest_bmi, encounter_date)) {
          if (bmi.value>=minBMI && bmi.value<maxBMI)
            return true;
          else if (dietary_consult.length>0)
            return true;
          else if (followup_plans.length>0)
            return true;
        }
      }
    }
    return false;
  }
  
  root.weight_exclusion = function(measure, earliest_encounter, effective_date) {
    var terminal_illness = actionFollowingSomething(measure.terminal_illness_patient_characteristic, measure.encounter_outpatient_encounter, year/2);
    var pregnant = inRange(measure.pregnancy_diagnosis_active, earliest_encounter, effective_date);
    var not_done = inRange(measure.physical_exam_not_done_physical_exam_not_done, earliest_encounter, effective_date);
    return pregnant || not_done || terminal_illness;
  }

}