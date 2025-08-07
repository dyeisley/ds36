#ifndef US_CITIES_H
#define US_CITIES_H

typedef struct {
    const char *city;
    const char *state;
} CityState;

#define US_CITY_COUNT 200

const CityState cityStates[US_CITY_COUNT] = {
    {"New York", "NY"}, {"Los Angeles", "CA"}, {"Chicago", "IL"}, {"Houston", "TX"}, {"Phoenix", "AZ"},
    {"Philadelphia", "PA"}, {"San Antonio", "TX"}, {"San Diego", "CA"}, {"Dallas", "TX"}, {"San Jose", "CA"},
    {"Austin", "TX"}, {"Jacksonville", "FL"}, {"Fort Worth", "TX"}, {"Columbus", "OH"}, {"Charlotte", "NC"},
    {"San Francisco", "CA"}, {"Indianapolis", "IN"}, {"Seattle", "WA"}, {"Denver", "CO"}, {"Washington", "DC"},
    {"Boston", "MA"}, {"El Paso", "TX"}, {"Nashville", "TN"}, {"Detroit", "MI"}, {"Oklahoma City", "OK"},
    {"Portland", "OR"}, {"Las Vegas", "NV"}, {"Memphis", "TN"}, {"Louisville", "KY"}, {"Baltimore", "MD"},
    {"Milwaukee", "WI"}, {"Albuquerque", "NM"}, {"Tucson", "AZ"}, {"Fresno", "CA"}, {"Sacramento", "CA"},
    {"Mesa", "AZ"}, {"Kansas City", "MO"}, {"Atlanta", "GA"}, {"Omaha", "NE"}, {"Colorado Springs", "CO"},
    {"Raleigh", "NC"}, {"Miami", "FL"}, {"Long Beach", "CA"}, {"Virginia Beach", "VA"}, {"Oakland", "CA"},
    {"Minneapolis", "MN"}, {"Tulsa", "OK"}, {"Arlington", "TX"}, {"Tampa", "FL"}, {"New Orleans", "LA"},
    {"Aurora", "CO"}, {"Honolulu", "HI"}, {"Anaheim", "CA"}, {"Santa Ana", "CA"}, {"Riverside", "CA"},
    {"Corpus Christi", "TX"}, {"Lexington", "KY"}, {"Henderson", "NV"}, {"Stockton", "CA"}, {"Saint Paul", "MN"},
    {"Cincinnati", "OH"}, {"St. Louis", "MO"}, {"Pittsburgh", "PA"}, {"Greensboro", "NC"}, {"Lincoln", "NE"},
    {"Anchorage", "AK"}, {"Plano", "TX"}, {"Orlando", "FL"}, {"Irvine", "CA"}, {"Newark", "NJ"},
    {"Toledo", "OH"}, {"Durham", "NC"}, {"Chula Vista", "CA"}, {"Fort Wayne", "IN"}, {"Jersey City", "NJ"},
    {"St. Petersburg", "FL"}, {"Laredo", "TX"}, {"Madison", "WI"}, {"Chandler", "AZ"}, {"Buffalo", "NY"},
    {"Lubbock", "TX"}, {"Scottsdale", "AZ"}, {"Reno", "NV"}, {"Glendale", "AZ"}, {"Gilbert", "AZ"},
    {"Winston-Salem", "NC"}, {"North Las Vegas", "NV"}, {"Norfolk", "VA"}, {"Chesapeake", "VA"}, {"Garland", "TX"},
    {"Irving", "TX"}, {"Hialeah", "FL"}, {"Fremont", "CA"}, {"Boise", "ID"}, {"Richmond", "VA"},
    {"Baton Rouge", "LA"}, {"Spokane", "WA"}, {"Des Moines", "IA"}, {"Tacoma", "WA"}, {"San Bernardino", "CA"},
    {"Modesto", "CA"}, {"Fontana", "CA"}, {"Santa Clarita", "CA"}, {"Birmingham", "AL"}, {"Oxnard", "CA"},
    {"Fayetteville", "NC"}, {"Moreno Valley", "CA"}, {"Rochester", "NY"}, {"Glendale", "CA"}, {"Huntington Beach", "CA"},
    {"Salt Lake City", "UT"}, {"Grand Rapids", "MI"}, {"Amarillo", "TX"}, {"Yonkers", "NY"}, {"Aurora", "IL"},
    {"Montgomery", "AL"}, {"Akron", "OH"}, {"Little Rock", "AR"}, {"Huntsville", "AL"}, {"Tempe", "AZ"},
    {"Columbus", "GA"}, {"Overland Park", "KS"}, {"Grand Prairie", "TX"}, {"Tallahassee", "FL"}, {"Cape Coral", "FL"},
    {"Mobile", "AL"}, {"Knoxville", "TN"}, {"Shreveport", "LA"}, {"Worcester", "MA"}, {"Ontario", "CA"},
    {"Vancouver", "WA"}, {"Sioux Falls", "SD"}, {"Chattanooga", "TN"}, {"Brownsville", "TX"}, {"Fort Lauderdale", "FL"},
    {"Providence", "RI"}, {"Newport News", "VA"}, {"Rancho Cucamonga", "CA"}, {"Santa Rosa", "CA"}, {"Peoria", "AZ"},
    {"Oceanside", "CA"}, {"Elk Grove", "CA"}, {"Salem", "OR"}, {"Pembroke Pines", "FL"}, {"Eugene", "OR"},
    {"Garden Grove", "CA"}, {"Cary", "NC"}, {"Fort Collins", "CO"}, {"Corona", "CA"}, {"Springfield", "MO"},
    {"Jackson", "MS"}, {"Alexandria", "VA"}, {"Hayward", "CA"}, {"Clarksville", "TN"}, {"Lakewood", "CO"},
    {"Lancaster", "CA"}, {"Salinas", "CA"}, {"Palmdale", "CA"}, {"Hollywood", "FL"}, {"Springfield", "MA"},
    {"Macon", "GA"}, {"Kansas City", "KS"}, {"Sunnyvale", "CA"}, {"Pomona", "CA"}, {"Killeen", "TX"},
    {"Escondido", "CA"}, {"Pasadena", "CA"}, {"Naperville", "IL"}, {"Bellevue", "WA"}, {"Joliet", "IL"},
    {"Murfreesboro", "TN"}, {"Midland", "TX"}, {"Rockford", "IL"}, {"Paterson", "NJ"}, {"Savannah", "GA"},
    {"Bridgeport", "CT"}, {"Torrance", "CA"}, {"McKinney", "TX"}, {"Surprise", "AZ"}, {"Denton", "TX"},
    {"Roseville", "CA"}, {"Thornton", "CO"}, {"Miramar", "FL"}, {"Pasadena", "TX"}, {"Mesquite", "TX"},
    {"Olathe", "KS"}, {"Dayton", "OH"}, {"Carrollton", "TX"}, {"Waco", "TX"}, {"Orange", "CA"},
    {"Fullerton", "CA"}, {"Charleston", "SC"}, {"West Valley City", "UT"}, {"Visalia", "CA"}, {"Hampton", "VA"},
    {"Gainesville", "FL"}, {"Warren", "MI"}, {"Coral Springs", "FL"}, {"Cedar Rapids", "IA"}, {"Round Rock", "TX"}
};

#endif // US_CITIES_H
