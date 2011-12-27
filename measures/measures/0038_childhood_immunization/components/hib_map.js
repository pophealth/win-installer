function () {
  var patient = this;
  var measure = patient.measures["0038"];
  if (measure==null)
    measure={};

  <%= init_js_frameworks %>

  var day = 24 * 60 * 60;
  var year = 365 * day;
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

  // patient needs 2 different hibluenza vaccines from the time that they 
  // are 180 days old, until the time that they are 2 years old
  var numerator = function() {
	return(hib_numerator(measure, patient.birthdate, effective_date));
  }

  var exclusion = function() {
    return (hib_exclusion(measure, patient.birthdate, effective_date));
  }


  map(patient, population, denominator, numerator, exclusion);
};
