/*
Generate cnp_vector_tb_inp.txt from random noise

Copyright 2019 Ahmet Inan <inan@aicodix.de>
*/

#include <fstream>
#include <functional>
#include <random>
#include "ldpc_vector.hh"

int main()
{
	std::random_device rd;
	typedef std::default_random_engine generator;
	typedef std::uniform_int_distribution<int> uniform;
	auto count = std::bind(uniform(COUNT_MIN, COUNT_MAX), generator(rd()));
	auto sequence = std::bind(uniform(0, ITERATIONS_MAX-1), generator(rd()));
	auto input = std::bind(uniform(-VMAG_MAX, VMAG_MAX), generator(rd()));
	auto previous = std::bind(uniform(-CMAG_MAX, CMAG_MAX), generator(rd()));
	auto wd_flag = std::bind(uniform(0, 1), generator(rd()));
	auto offset = std::bind(uniform(0, CODE_VECTORS-1), generator(rd()));
	auto shift = std::bind(uniform(0, VECTOR_SCALARS-1), generator(rd()));
	auto location = std::bind(uniform(0, VECTOR_LOCATIONS_MAX-1), generator(rd()));

	std::ofstream vector_input("cnp_vector_tb_inp.txt");

	for (int i = 0; i < 100; ++i) {
		int cnt = count();
		int seq = sequence();
		vector_input << cnt << '\t' << seq << std::endl;
		for (int j = 0; j < cnt; ++j) {
			vector_input << (wd_flag() ? "TRUE" : "FALSE") << '\t';
			vector_input << location() << '\t';
			vector_input << offset() << ':' << shift();
			for (int k = 0; k < VECTOR_SCALARS; ++k)
				vector_input << '\t' << input();
			for (int k = 0; k < VECTOR_SCALARS; ++k)
				vector_input << '\t' << previous();
			vector_input << std::endl;
		}
	}
	return 0;
}
