#include <iostream>
#include <stdlib.h>
#include <stdio.h>
#include <vector>
#include <string>
#include <Windows.h>
#include <winreg.h>
#include <windef.h>
#include <limits>
#include <conio.h>
#include <map>
#include <fstream>
#include <iostream>
#include <sys/stat.h>
#include <fileapi.h>
#include <chrono>
#include <thread>


std::vector<std::string> getPorts() 
{
    std::vector<std::string> ports;
    HKEY hKey;
    LONG lResult;

    // open key
    lResult = RegOpenKeyEx(HKEY_LOCAL_MACHINE, TEXT("HARDWARE\\DEVICEMAP\\SERIALCOMM"), 0, KEY_READ, &hKey);
    if(lResult != ERROR_SUCCESS) {
        std::cout << "error opening key." << std::endl;
        return ports;
    }

    
    DWORD dwIndex = 0;
    char keyName[256];
    byte dataValue[256];
    DWORD keyNameLength = sizeof(keyName);
    DWORD dataValueLength = sizeof(dataValue);
    int portCount = 1;

    std::cout << std::endl << "\x1b[1m\x1b[4m" << "available ports: " << "\x1b[22m\x1b[24m" << std::endl;

    // enumerate and read subkeys (first result 0 index then incremenet)
    lResult = RegEnumValueA(hKey, dwIndex, keyName, &keyNameLength, NULL, NULL, dataValue, &dataValueLength);
    while (lResult == ERROR_SUCCESS) {
        keyNameLength = sizeof(keyName);
        dataValueLength = sizeof(dataValue);
        
        std::cout << portCount++ << ". " << (char*)dataValue << std::endl;
        ports.push_back((char*)dataValue);
        lResult = RegEnumValueA(hKey, ++dwIndex, keyName, &keyNameLength, NULL, NULL, dataValue, &dataValueLength);
    }

    /*if (lResult == ERROR_NO_MORE_ITEMS) {
        std::cout << std::endl << "subkeys all enumerated successfully." << std::endl;
    }*/

    RegCloseKey(hKey);

    return ports;
}

bool openSerial(std::string port, int baud, HANDLE &hCommPort) 
{
    std::string portPath = "\\\\.\\" + port;
    hCommPort = CreateFileA(portPath.c_str(), GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if(hCommPort == INVALID_HANDLE_VALUE) {
        return false;
    }

    DCB dcbCommPort;
    SecureZeroMemory(&dcbCommPort, sizeof(DCB));
    dcbCommPort.DCBlength = sizeof(DCB);
    // get comm port settings
    GetCommState(hCommPort, &dcbCommPort);
    // congifure port (baud, data length, parity, stop bits)
    dcbCommPort.BaudRate = baud;
    dcbCommPort.ByteSize = 8;
    dcbCommPort.Parity = NOPARITY;
    dcbCommPort.StopBits = ONESTOPBIT;
    //update the port
    if(!SetCommState(hCommPort, &dcbCommPort)) {
        return false;
    }

    // set timeout values for serial writing
    COMMTIMEOUTS commPortTimeouts;
    commPortTimeouts.ReadIntervalTimeout = 1;
    commPortTimeouts.ReadTotalTimeoutMultiplier = 1;
    commPortTimeouts.ReadTotalTimeoutMultiplier = 1;
    commPortTimeouts.WriteTotalTimeoutConstant = 1;
    commPortTimeouts.WriteTotalTimeoutMultiplier = 1;
    // update timeouts
    if(!SetCommTimeouts(hCommPort, &commPortTimeouts)) {
        return false;
    }

    return true;
}

int main() 
{
    std::vector<std::string> ports = getPorts();
    size_t portSize = ports.size();

    // get port
    int sel;
    std::cout << "select port (1-" << portSize << "): ";
    while(true) {
        std::cin >> sel;
        if(std::cin.fail() || sel < 1 || sel > portSize) {
            std::cin.clear();
            std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
            std::cout << "invalid try again (1-" << portSize << "): ";
            continue;
        }
        break;
    }
    std::string port = ports[sel - 1];

    // open serial connection
    HANDLE hCommPort;
    if(!openSerial(port, 115200, hCommPort)) {
        std::cout << "unable to open serial connection at port " << port << ". exiting. ";
        return 0;
    } 

    // main loop for sending raw iq data
    std::ifstream file("adsb_capture.bin", std::ios::binary);
    if(file) {
        // file length
        file.seekg(0, file.end);
        size_t len = file.tellg();
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
        std::cout << std::endl << "press Enter to start sending: ";
        while(_getch() != 13) {}
        std::cout << std::endl << "sending... ";
        for(size_t i = 0; i < len; i++) {
            DWORD numBytesWritten;
            uint8_t data = buffer[i]; 
            WriteFile(hCommPort, &data, 1, &numBytesWritten, NULL);
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
        CloseHandle(hCommPort);
        delete[] buffer;
    }

    // main loop for sending magnitudes
    /*std::ifstream readfile("adsb_norm.txt");
    int valueToSend;
    std::cout << std::endl << "press Enter to start sending: ";
    while(_getch() != 13) {}
    std::cout << std::endl << "sending... ";
    while(readfile >> valueToSend) {
        DWORD numBytesWritten;
        uint8_t byteToSend = (uint8_t)valueToSend;
        WriteFile(hCommPort, &byteToSend, 1, &numBytesWritten, NULL);
    }
    CloseHandle(hCommPort);*/

    return 0;
}