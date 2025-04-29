#include "md5.h"
#include <iomanip>
#include <iostream>
#include <cassert>
#include <chrono>
#include <vector>

using namespace std;
using namespace chrono;

// g++ -O2 -g md5.cpp profiling.cpp -mcpu=cortex-a76 -o nor_perf_test
// g++ -O2 -g md5.cpp profiling.cpp -mcpu=cortex-a76 -o par_perf_test

// 测试数据集生成
vector<string> generate_test_data(int count, size_t length) {
    vector<string> data;
    for (int i = 0; i < count; ++i) {
        string s(length, '\0');
        for (size_t j = 0; j < length; ++j) {
            s[j] = static_cast<char>((i + j) % 256);
        }
        data.push_back(s);
    }
    return data;
}

// 标准MD5测试函数
void test_standard_md5(const vector<string>& data) {
    bit32 state[4];
    for (const auto& s : data) {
        MD5Hash(s, state);
    }
}

// SIMD MD5测试函数
void test_simd_md5(const vector<string>& data) {
    // 确保数据量是4的倍数
    assert(data.size() % 4 == 0);
    
    uint32_t state[4][4];
    for (size_t i = 0; i < data.size(); i += 4) {
        string inputs[4] = {data[i], data[i+1], data[i+2], data[i+3]};
        SIMD_MD5Hash(inputs, state);
    }
}

int main() {
    // 生成测试数据
    auto test_data = generate_test_data(80000, 8);

    // 测试标准MD5
    // test_standard_md5(test_data);

    // 测试SIMD MD5 (确保数据量是4的倍数)
    // test_simd_md5(test_data);

    return 0;
}