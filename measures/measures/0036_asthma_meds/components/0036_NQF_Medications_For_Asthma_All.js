function () {
  var patient = this;
  var measure = patient.measures["0036"];
  if (measure==null)
    measure={};

  <%= init_js_frameworks %>

  var day = 24*60*60;
  var year = 365*day;
  var effective_date = <%= effective_date %>;
  /*
    “Patient characteristic: birth date” (age) >=4 and <=49 before the “measurement period” 
     to capture all patients who will reach the age of 5 through 50 during the “measurement period”;
   */
  var earliest_birthdate = effective_date - 49*year;
  var latest_birthdate = effective_date - 4*year;
  var earliest_encounter = effective_date - 2*year; // <= 1 years before or simultaneously to the  “measurement period”; 

  var population = function() {
    return inRange(patient.birthdate, earliest_birthdate, latest_birthdate);
  }
  
  var denominator = function() {
    return asthmaDenominator(measure, earliest_birthdate, effective_date);
  }
  
  var numerator = function() {
    return asthmaNumerator(measure, earliest_birthdate, effective_date);
  }
  
  var exclusion = function() {
    return asthmaExclusion(measure);
  }
  
  map(patient, population, denominator, numerator, exclusion);
};
