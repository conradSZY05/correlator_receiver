#include <iostream>
#include <fstream>
#include <cstdint>
#include <vector>


int main() 
{
    std::ifstream readfile("adsb_norm.txt");

    std::vector<int> preamble = {1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0};
    std::vector<int> shift_vec(16);
    int mag;
    int count = 0;
    
    while(readfile >> mag) {
        //std::cout << mag << std::endl;

        // shift vector to the left and assign new sample
        for(int i = 0; i < shift_vec.size() - 1; i++) {
            shift_vec[i] = shift_vec[i+1];
        }
        shift_vec[shift_vec.size() - 1] = mag;
        count++;

        if(count < 16) continue; // only correlate when shift_vec is filled

        int preamble_magnitude = 0;
        for(int i = 0; i < preamble.size(); i++) {
            preamble_magnitude += shift_vec[i] * preamble[i];
        }

        // check if preamble detected
        if(preamble_magnitude >= 400) {
            std::cout << "preamble detected" << count << std::endl;
        }

    }
    
    return 0;
}