#include <iostream>
#include <fstream>
#include <cmath>
#include <cstdint>

int main()
{
    // open
    std::ifstream file("adsb_capture.bin", std::ios::binary);

    if(file) {
        // file length
        file.seekg(0, file.end);
        int len = file.tellg();
        file.seekg(0, file.beg);

        uint8_t* buffer = new uint8_t[len]; // cant use char because itll read it as signed

        std::cout << "reading... " << len << " characters" << std::endl;

        file.read((char*)buffer, len);

        if(file)
            std::cout << "file read successfully" << std::endl;
        else
            std::cout << "error only " << file.gcount() << " could be read" << std::endl;

        file.close();

        // buffer contains whole file
        // print first 5000 magnitudes
        for(size_t i = 34240; i < 2000+34240; i += 2) {
            // read two at a time (I and Q)
            float I = (float)buffer[i] - 127.5f;
            float Q = (float)buffer[i+1] - 127.5f;
            float mag = sqrtf(I*I + Q*Q);
            //165.362 127.932
            std::cout << "line " << i << ", ";
            std::cout << "I = " << I << ", ";
            std::cout << "Q = " << Q << ", ";
            std::cout << "magnitude = " << (float)(mag) << std::endl;
            
           

        }
        //std::ofstream writefile;
        //writefile.open("adsb_norm.txt");

        delete[] buffer;
    }
    
    return 0;
}