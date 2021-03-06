-- vector variable nodes
--
-- Copyright 2019 Ahmet Inan <inan@aicodix.de>

library ieee;
use ieee.std_logic_1164.all;
use work.ldpc_vector.all;

entity var_vector is
	generic (
		size : positive
	);
	port (
		clock : in std_logic;
		wren : in boolean;
		rden : in boolean;
		wpos : in natural range 0 to size-1;
		rpos : in natural range 0 to size-1;
		isft : in vsft_vector;
		osft : out vsft_vector
	);
end var_vector;

architecture rtl of var_vector is
begin
	vector_inst : for idx in soft_vector'range generate
		scalar_inst : entity work.var_scalar
			generic map (size)
			port map (clock, wren, rden, wpos, rpos,
				isft(idx), osft(idx));
	end generate;
end rtl;

