#include <string>

extern "C" std::string std__string_CcharP(char* c){
    return std::string(c);
}

extern "C" void std__string_D(std::string* c){
    std::string((std::string&&)*c);
}