/*
check table_scalar.txt for data hazards

Copyright 2019 Ahmet Inan <inan@aicodix.de>
*/

#include <fstream>
#include <iostream>
#include "ldpc_scalar.hh"

const int PIPELINE_LENGTH = 7;

int main()
{
	int offsets[BLOCK_PARITIES_MAX][COUNT_MAX];
	int shifts[BLOCK_PARITIES_MAX][COUNT_MAX];
	int counts[BLOCK_PARITIES_MAX];
	int parities = 0;
	std::ifstream table_txt("table_scalar.txt");
	for (; table_txt >> counts[parities]; ++parities) {
		for (int num = 0; num < counts[parities]; ++num) {
			table_txt >> offsets[parities][num];
			table_txt.ignore(1, ':');
			table_txt >> shifts[parities][num];
		}
	}
	int violations = 0;
	for (int pty0 = 0; pty0 < parities; ++pty0) {
		int pty1 = (pty0 + 1) % parities;
		int delay = (PIPELINE_LENGTH + 2 * counts[pty0] - 1) / counts[pty0];
		for (int end0 = BLOCK_SCALARS-delay; end0 < BLOCK_SCALARS; ++end0) {
			for (int beg1 = 0; beg1 < delay; ++beg1) {
				for (int num0 = 0; num0 < counts[pty0]; ++num0) {
					for (int num1 = 0; num1 < counts[pty1]; ++num1) {
						int wdf = !beg1 && offsets[pty1][num1] == CODE_BLOCKS-1 && shifts[pty1][num1] == BLOCK_SCALARS-1;
						int shi0 = (shifts[pty0][num0]+end0)%BLOCK_SCALARS;
						int shi1 = (shifts[pty1][num1]+beg1)%BLOCK_SCALARS;
						if (!wdf && offsets[pty0][num0] == offsets[pty1][num1] && shi0 == shi1) {
							std::cout << "consecutive parities " << pty0 << " at " << end0 << " and " << pty1 << " at " << beg1 << " have same location shift " << shi0 << " at block offset " << offsets[pty0][num0] << std::endl;
							++violations;
						}
					}
				}
			}
		}
	}
	if (violations)
		std::cout << violations;
	else
		std::cout << "no";
	std::cout << " violations detected." << std::endl;
	return !!violations;
}
