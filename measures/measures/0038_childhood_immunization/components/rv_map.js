function () {
  var patient = this;
  var measure = patient.measures["0038"];
  if (measure==null)
    measure={};

  <%= init_js_frameworks %>

  var year = 365 * 24 * 60 * 60;
  var effective_date =  <%= effective_date %>;
  var earliest_birthdate =  effective_date - 2 * year;
  var latest_birthdate =    effective_date - 1 * year;

  var population = function() {
    return inRange(patient.birthdate, earliest_birthdate, latest_birthdate);
  }

  // the denominator logic is the same for all of the 0038 reports and this 
  // code is defined in the shared library in the project in the code from 
  // /js/childhood_immunizations.js
  var denominator = function() {
    return has_outpatient_encounter_with_pcp_obgyn(measure, patient.birthdate, effective_date);
  }

  // To meet the criteria for this report, the patient needs to have either:
  // 2 Rotavirus (RV) vaccines up until the time that they are 2 years old
  var numerator = function() {
    return(rv_numerator(measure, patient.birthdate, effective_date));
  }
   // Exclude patients who have a Medication allergy to RV vaccine
  var exclusion = function() {
    return (rv_exclusion(measure, patient.birthdate, effective_date));
  }
 
  map(patient, population, denominator, numerator, exclusion);
};
