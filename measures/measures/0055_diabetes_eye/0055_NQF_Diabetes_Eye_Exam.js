function() {
  var patient = this;
  var measure = patient.measures["0055"];
  if (measure == null)
    measure={};

  <%= init_js_frameworks %>

  // TODO: rjm Get these definitions into the 'diabetes_utils.js' file
  // that is located in the /js directory of the project for shared 
  // code across all of the diabetes measures.
  var day = 24 * 60 * 60;
  var year = 365 * day;
  var effective_date =                <%= effective_date %>;
  var measurement_period_start =          effective_date - (1 * year);

  var measurement_period_start =          effective_date - year;
  var earliest_birthdate =                measurement_period_start - (75 * year);
  var latest_birthdate =                  measurement_period_start - (18 * year);

  var earliest_diagnosis =                effective_date - (2 * year);
  var year_prior_to_measurement_period =  effective_date - (2 * year);

  var population = function() {
    return diabetes_population(patient, earliest_birthdate, latest_birthdate);
  }

  var denominator = function() {
    return diabetes_denominator(measure, earliest_diagnosis, effective_date);
  }

  // This numerator function is the only code that is specific to this particular
  // MU diabetes measure.  All of the other definitions for the initial population,
  // the denominator, and the exclusions are shared in the 'diabetes_utils.js' file
  // that is located in the /js directory of the project
  var numerator = function() {
    return (inRange(measure.eye_exam_procedure_performed, measurement_period_start, effective_date)
            || (inRange(measure.eye_exam_procedure_performed, year_prior_to_measurement_period, measurement_period_start)
                && 
                !inRange(measure.diabetic_retinopathy_diagnosis_active, year_prior_to_measurement_period, measurement_period_start))
            );
  }

  var exclusion = function() {
    return diabetes_exclusions(measure, earliest_diagnosis, effective_date);
  }

  map(patient, population, denominator, numerator, exclusion);
};