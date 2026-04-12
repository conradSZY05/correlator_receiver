#include <iostream>
#include <fstream>
#include <cstdint>
#include <vector>
#include <numeric>
#include <bitset>
#include <sstream>
#include <iomanip>
#include <cmath>
#include <unordered_map>

#define THRESHOLD_FACTOR 4
#define MIN_FRAME 112

uint32_t modes_checksum_table[112] = {
    0x3935ea, 0x1c9af5, 0xf1b77e, 0x78dbbf, 0xc397db, 0x9e31e9, 0xb0e2f0, 0x587178,
    0x2c38bc, 0x161c5e, 0x0b0e2f, 0xfa7d13, 0x82c48d, 0xbe9842, 0x5f4c21, 0xd05c14,
    0x682e0a, 0x341705, 0xe5f186, 0x72f8c3, 0xc68665, 0x9cb936, 0x4e5c9b, 0xd8d449,
    0x939020, 0x49c810, 0x24e408, 0x127204, 0x093902, 0x049c81, 0xfdb444, 0x7eda22,
    0x3f6d11, 0xe04c8c, 0x702646, 0x381323, 0xe3f395, 0x8e03ce, 0x4701e7, 0xdc7af7,
    0x91c77f, 0xb719bb, 0xa476d9, 0xadc168, 0x56e0b4, 0x2b705a, 0x15b82d, 0xf52612,
    0x7a9309, 0xc2b380, 0x6159c0, 0x30ace0, 0x185670, 0x0c2b38, 0x06159c, 0x030ace,
    0x018567, 0xff38b7, 0x80665f, 0xbfc92b, 0xa01e91, 0xaff54c, 0x57faa6, 0x2bfd53,
    0xea04ad, 0x8af852, 0x457c29, 0xdd4410, 0x6ea208, 0x375104, 0x1ba882, 0x0dd441,
    0xf91024, 0x7c8812, 0x3e4409, 0xe0d800, 0x706c00, 0x383600, 0x1c1b00, 0x0e0d80,
    0x0706c0, 0x038360, 0x01c1b0, 0x00e0d8, 0x00706c, 0x003836, 0x001c1b, 0xfff409,
    0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000,
    0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000,
    0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000
};

struct Aircraft 
{
    int lateven = 0, latodd = 0;
    int loneven = 0, lonodd = 0;
};

double NL(double lat) {
    double z = cos((M_PI / 180) * fabs(lat));
    double x = 1 - ((1 - cos(M_PI / 30)) / (z * z));
    return 2.0 * M_PI * pow(acos(x),-1);
}

int extract_bits(std::bitset<MIN_FRAME> frame, int numbits, int start) 
{
    int extracted_int = 0;
    for(int i = start; i < start+numbits; i++) {
        extracted_int <<= 1;
        extracted_int |= frame[i];
    }
    return extracted_int;
}

int main() 
{
    std::ifstream readfile("adsb_norm.txt");

    std::vector<int> preamble = {1, -1, 1, -1, -1, -1, -1, 1, -1, 1, -1, -1, -1, -1, -1, -1};
    std::vector<int> shift_vec(16);
    int mag;
    int count = 0;
    bool detected = false;
    float noise_estimate = 6.f;
    int cooldown = 0;
    bool skip = false;
    int preamble_magnitude;
    float threshold;
    
    //decoding
    int decoded = 0;
    std::bitset<MIN_FRAME> frame;
    int bit_index = 0;
    int first_half = 0;
    std::string callsign;
    float speed, heading;
    std::unordered_map<int, Aircraft> aircraft_map;

    double lat = 0, lon = 0;

    while(readfile >> mag) {
        //std::cout << mag << std::endl;

        if(detected) {
            if(skip) {
                skip = false;
            } else {
                // decode
                if(first_half == 0) {
                    first_half = mag;
                } else {
                    if(bit_index == MIN_FRAME) {
                        bool valid_signal = true;
                        bit_index = 0;

                        // downlink format
                        int df = extract_bits(frame, 5, 0);
                        //transponder capability
                        int ca = extract_bits(frame, 3, 5);
                        // ICAO ADDRESS
                        int ICAO_address = extract_bits(frame, 24, 8);
                        // type code
                        int tc = extract_bits(frame, 5, 32);
                        // parity/interrogator ID
                        int pi = extract_bits(frame, 24, 88);
                        
                        uint32_t gen_polynomial = 0xFFFA04D;
                        std::bitset<24> pi_bits = std::bitset<24>(pi);
                        uint32_t crc = 0;
                        // CRC check
                        if(df == 17 || df == 18) {
                            // message is 112 bits for df 17
                            for(int i = 0; i < 88; i++) {
                                if(frame[i]) {
                                    crc ^= modes_checksum_table[i];
                                }
                            }
                            crc &= 0x00FFFFFF; // keep 24 bits

                        }
                        
                        if(crc != pi) { // invalid
                            valid_signal = false;
                        } else {
                            decoded++;
                            callsign = "";
                            speed = 0.f;
                            heading = 0.f;
                            lat = 0;
                            lon = 0;
                            if(tc >= 1 && tc <= 4) {
                                // callsign
                                for(int i = 0; i < 8; i++) {
                                    int part = extract_bits(frame, 6, 40 + i * 6);

                                    char c;
                                    if(part == 0) c = ' ';
                                    else if(part >= 1 && part <= 26) c = 'A' + part - 1;
                                    else if(part >= 48 && part <= 57) c = '0' + part - 48;
                                    else c = ' ';

                                    callsign += c;
                                }
                            } else if(tc >= 9 && tc <= 18) {
                                Aircraft& ac = aircraft_map[ICAO_address];
                                int flag = extract_bits(frame, 1, 53);
                                if(!flag) {
                                    // even
                                    ac.lateven = extract_bits(frame, 17, 54);
                                    ac.loneven = extract_bits(frame, 17, 71);
                                } else {
                                    // odd
                                    ac.latodd = extract_bits(frame, 17, 54);
                                    ac.lonodd = extract_bits(frame, 17, 71);
                                }
                                
                                if(ac.lateven != 0 && ac.latodd != 0) {
                                    // normalise
                                    double YZeven = (double)ac.lateven / 131072;
                                    double XZeven = (double)ac.loneven / 131072;
                                    double YZodd = (double)ac.latodd / 131072;
                                    double XZodd = (double)ac.lonodd / 131072;

                                    // lat
                                    double j = floor(59 * YZeven - 60 * YZodd + 0.5); // lat index
                                    double lat_even = (360.0 / 60.0) * (std::fmod(j,60) + YZeven);
                                    double lat_odd = (360.0 / 59.0) * (std::fmod(j,59) + YZodd);
                                    lat = flag ? lat_odd : lat_even;
                                    if(lat > 270) lat -= 360; // if lat in southern hemisphere subtract 360

                                    // lon
                                    double m = floor((XZeven * (NL(lat) - 1) - XZodd * NL(lat) + 0.5));
                                    double n = !flag ? fmax(NL(lat), 1) : fmax(NL(lat) - 1, 1);
                                    double XZlatest = flag ? XZodd : XZeven;
                                    lon = (360.0 / n) * (fmod(m, n) + XZlatest);

                                    ac.lateven = 0;
                                    ac.latodd = 0;
                                    ac.loneven = 0;
                                    ac.lonodd = 0;
                                }
                            } else if(tc == 19) {
                                // speed and heading
                                int subtype = extract_bits(frame, 3, 38);
                                int intent_change = extract_bits(frame, 1, 39);
                                int dir_ew = extract_bits(frame, 1, 45);
                                int vel_ew = extract_bits(frame, 10, 46);
                                int dir_ns = extract_bits(frame, 1, 56);
                                int vel_ns = extract_bits(frame, 10, 57);

                                // knots
                                vel_ew = dir_ew == 1 ? vel_ew * -1 : vel_ew;
                                vel_ns = dir_ns == 1 ? vel_ns * -1 : vel_ns;

                                speed = sqrt(vel_ew * vel_ew + vel_ns * vel_ns);
                                heading = atan2(vel_ew, vel_ns) * 180 / M_PI;
                                if(heading < 0) heading += 360; // adjust 0 to 360 if needed
                            } 
                        }

                        if(valid_signal) {
                            //std::cout << "computed crc: " << std::hex << crc << std::endl;
                            //std::cout << "transmitted pi: " << std::hex << pi << std::endl << std::dec;
                            std::cout << "------- RAW DATA -------" << std::endl;
                            for(int i = 0; i < shift_vec.size(); i++) {
                                std::cout << shift_vec[i] << " ";
                            }
                            std::cout << std::endl;
                            std::cout << "preamble magnitude " << preamble_magnitude << std::endl;
                            std::cout << "noise " << noise_estimate << std::endl;
                            std::cout << "using threshold " << threshold << std::endl;
                            std::cout << "preamble detected at " << count-15 << std::endl;
                            // remember frame is reversed
                            for(int i = 0; i < frame.size(); i++) {
                                std::cout << frame[i];
                            }
                            std::cout << std::endl;

                            std::cout << "------- EXTRACTED DATA -------" << std::endl;
                            std::cout << "df " << df << " | ";
                            std::cout << "ca " << ca << " | ";
                            std::cout << "address " << std::hex << std::setw(6) << std::setfill('0') << ICAO_address << " | " << std::dec;
                            std::cout << "type code " << tc << " | ";
                            std::cout << "parity/interrogator ID " << pi << std::endl;

                            std::cout << "------- DECODED DATA -------" << std::endl;
                            if(callsign != "") {
                                std::cout << "callsign " << callsign << std::endl;
                            } else if (speed != 0 && heading != 0) {
                                std::cout << "speed " << speed << std::endl;
                                std::cout << "heading " << heading << std::endl;
                            } else if (lat != 0 && lon != 0) {
                                std::cout << "lat " << std::fixed << std::setprecision(6) << lat << std::endl; // last two decimal figures dont really make much difference 
                                std::cout << "lon " << std::fixed << std::setprecision(6) << lon << std::endl;

                            }
                            std::cout << std::endl;
                        }
                        detected = false;
                    } else {
                        int second_half = mag;
                        frame[bit_index] = first_half > second_half;
                        bit_index++;
                    }

                    first_half = 0;
                }
            }
        } else {
            // shift vector to the left and assign new sample
            for(int i = 0; i < shift_vec.size() - 1; i++) {
                shift_vec[i] = shift_vec[i+1];
            }
            shift_vec[shift_vec.size() - 1] = mag;
            count++;

            if(count < 16) continue; // only correlate when shift_vec is filled

            preamble_magnitude = 0;
            noise_estimate = 0.999f * noise_estimate + 0.001f * mag;
            float local_average = std::accumulate(shift_vec.begin(), shift_vec.end(), 0) / 16;
            //std::cout << local_average << std::endl;
            for(int i = 0; i < preamble.size(); i++) {
                preamble_magnitude += (shift_vec[i] - noise_estimate) * preamble[i];
            }

            // check if preamble detected
            threshold = noise_estimate * 4 * THRESHOLD_FACTOR;
            if(preamble_magnitude >= threshold) {
                // check the peaks are actually at the right position
                int gate = noise_estimate * 4;
                if(shift_vec[0] > gate && 
                   shift_vec[2] > gate && 
                   shift_vec[7] > gate &&
                   shift_vec[9] > gate) {
                    detected = true;
                    bit_index = 0;
                    first_half = 0;
                    skip = false;
                }
            }
        }
    }
    
    std::cout << std::endl << "decoded " << decoded << " signals.";

    return 0;
}