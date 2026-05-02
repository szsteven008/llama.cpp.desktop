//
//  Server.hpp
//  llama.cpp.desktop
//
//  Created by steve.tang on 2026/4/28.
//

#ifndef Server_hpp
#define Server_hpp

#include <vector>
#include <string>

std::vector<std::string> models();
std::string base_uri();

void start();
void stop();

std::string log_get();

#endif /* Server_hpp */
