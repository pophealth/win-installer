function() {
  var patient = this;
  var measure = patient.measures["0027"];
  if (measure == null)
    measure={};

  <%= init_js_frameworks %>

  var day = 24 * 60 * 60;
  var year = 365 * day;
  var effective_date =        <%= effective_date %>;

  var measurement_period_start =  effective_date - (1 * year);
  var latest_birthdate =          measurement_period_start - (17 * year);

  var earliest_encounter =        effective_date - (2 * year);
  var earliest_tobacco_user =     effective_date - (1 * year);

  var population = function() {
    return (patient.birthdate <= latest_birthdate);
  }

  var denominator = function() {
    return inRange(measure.encounter_outpatient_encounter, earliest_encounter, effective_date);
  }

  var numerator = function() {
    return inRange(measure.tobacco_user_physical_exam_finding, earliest_tobacco_user, effective_date);
  }

  var exclusion = function() {
    return false;
  }

  map(patient, population, denominator, numerator, exclusion);
};