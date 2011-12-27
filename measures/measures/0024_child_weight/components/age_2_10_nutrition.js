function() {
  var patient = this;
  var measure = patient.measures["0024"];
  if (measure == null)
    measure={};

  <%= init_js_frameworks %>

  var day = 24 * 60 * 60;
  var year = 365 * day;
  var effective_date =        <%= effective_date %>;

  var measurement_period_start =  effective_date - (1 * year);
  var earliest_birthdate  =       measurement_period_start - (10 * year);
  var latest_birthdate =          measurement_period_start - (2 * year);

  var population = function() {
    return weight_population(patient,
                             earliest_birthdate,
                             latest_birthdate);
  }
  
  var denominator = function() {
    return weight_denominator(measure,
                              measurement_period_start,
                              effective_date);
  }

  var numerator = function() {
    return inRange(measure.counseling_for_nutrition_communication_to_patient,
                   measurement_period_start,
                   effective_date);
  }

  var exclusion = function() {
    return false;
  }

  map(patient, population, denominator, numerator, exclusion);
};