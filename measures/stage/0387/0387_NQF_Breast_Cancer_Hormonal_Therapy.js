function () {
  var patient = this;
  var measure = patient.measures["0387"];
  if (measure==null)
    measure={};

  <%= init_js_frameworks %>

  var day = 24*60*60;
  var year = 365*day;
  var effective_date = <%= effective_date %>;
  var latest_birthdate = effective_date - 23*year;
  var latest_birthdate = effective_date - 15*year;
  var earliest_encounter = effective_date - 1*year;
 
  var population = function() {
     
    return false ;
  }
  
  var denominator = function() {

    return false;
  }
  
  var numerator = function() {
  
    return false;
  }
  
  var exclusion = function() {


     return false

  }
  
  map(patient, population, denominator, numerator, exclusion);
};
