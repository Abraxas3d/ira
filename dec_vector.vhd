-- SISO vector decoder for IRA-LDPC codes
--
-- Copyright 2019 Ahmet Inan <inan@aicodix.de>

library ieee;
use ieee.std_logic_1164.all;
use work.ldpc.all;
use work.table.all;

entity dec_vector is
	port (
		clock : in std_logic;
		busy : out boolean := false;
		istart : in boolean;
		ostart : out boolean := false;
		isoft : in soft_scalar;
		osoft : out soft_scalar
	);
end dec_vector;

architecture rtl of dec_vector is
	signal swap_cv : natural range 0 to code_vectors := code_vectors;
	signal swap_bv : natural range 0 to block_vectors-1;
	subtype vector_index is natural range 0 to vector_scalars-1;
	signal swap_vs : vector_index;
	type swap_vs_delays is array (1 to 2) of vector_index;
	signal swap_vs_d : swap_vs_delays;
	signal prev_vsft : vsft_scalar;
	signal var_wren, var_rden : boolean := false;
	signal var_wpos, var_rpos : natural range 0 to code_vectors-1;
	signal var_isft, var_osft : vsft_vector;
	signal bnl_wren, bnl_rden : boolean := false;
	signal bnl_wpos, bnl_rpos : location_scalar;
	signal bnl_isft, bnl_osft : csft_vector;
	signal first_wdf : boolean;
	signal wdf_wren, wdf_rden : boolean := false;
	signal wdf_wpos, wdf_rpos : location_scalar;
	signal wdf_iwdf, wdf_owdf : boolean;
	signal loc_wren, loc_rden : boolean := false;
	signal loc_wpos, loc_rpos : location_scalar;
	signal loc_ioff, loc_ooff : offset_scalar;
	signal loc_ishi, loc_oshi : shift_scalar;
	signal cnt_wren : boolean := false;
	signal cnt_wpos, cnt_rpos : natural range 0 to parities_max-1;
	signal cnt_icnt, cnt_ocnt : count_scalar;
	signal cnp_start : boolean := false;
	signal cnp_count : count_scalar;
	signal cnp_busy, cnp_valid : boolean;
	signal cnp_iseq, cnp_oseq : sequence_scalar;
	signal cnp_ivsft, cnp_ovsft : vsft_vector;
	signal cnp_ocsft : csft_vector;
	signal cnp_iwdf, cnp_owdf : boolean;
	signal cnp_iloc, cnp_oloc : location_scalar;
	signal cnp_ioff, cnp_ooff : offset_scalar;
	signal cnp_ishi, cnp_oshi : shift_scalar;
	signal rol_shift : natural range 0 to soft_vector'length-1;
	signal rol_ivsft, rol_ovsft : vsft_vector;
	signal ror_clken : boolean;
	signal ror_shift : natural range 0 to soft_vector'length-1;
	signal ror_ivsft, ror_ovsft : vsft_vector;
	signal sub_clken : boolean;
	signal sub_ivsft, sub_ovsft : vsft_vector;
	signal sub_icsft, inv_sub_icsft : csft_vector;
	signal add_ivsft, add_ovsft : vsft_vector;
	signal add_icsft : csft_vector;
	signal ptys : parities := init_parities;
	signal inp_pty : natural range 0 to parities_max;
	signal prev_start : boolean := false;
	type swap_start_delays is array (1 to 2) of boolean;
	signal swap_start_d : swap_start_delays := (others => false);
	signal inp_seq, out_seq : sequence_scalar;
	type inp_stages is array (0 to 8) of boolean;
	signal inp_stage : inp_stages := (others => false);
	type swap_stages is array (0 to 3) of boolean;
	signal swap_stage : swap_stages := (others => false);
	type swap_soft_delays is array (1 to 2) of soft_scalar;
	signal swap_soft_d : swap_soft_delays;
	signal swap_pos, swap_dpos : natural range 0 to code_vectors-1;
	subtype num_scalar is natural range 0 to degree_max;
	signal inp_num : num_scalar := 0;
	signal inp_cnt : count_scalar := degree_max;
	signal inp_loc : location_scalar;
	type out_stages is array (1 to 5) of boolean;
	signal out_stage : out_stages := (others => false);
	type out_off_delays is array (1 to 4) of offset_scalar;
	signal out_off_d : out_off_delays;
	type out_shi_delays is array (1 to 2) of shift_scalar;
	signal out_shi_d : out_shi_delays;
	type out_wdf_delays is array (1 to 4) of boolean;
	signal out_wdf_d : out_wdf_delays;
	type inp_num_delays is array (1 to 8) of num_scalar;
	signal inp_num_d : inp_num_delays;
	type inp_cnt_delays is array (1 to 8) of count_scalar;
	signal inp_cnt_d : inp_cnt_delays;
	type inp_seq_delays is array (1 to 8) of sequence_scalar;
	signal inp_seq_d : inp_seq_delays;
	type inp_loc_delays is array (1 to 8) of location_scalar;
	signal inp_loc_d : inp_loc_delays;
	type inp_wdf_delays is array (1 to 6) of boolean;
	signal inp_wdf_d : inp_wdf_delays;
	type inp_off_delays is array (1 to 6) of offset_scalar;
	signal inp_off_d : inp_off_delays;
	type inp_shi_delays is array (1 to 6) of shift_scalar;
	signal inp_shi_d : inp_shi_delays;

	function inv (val : csft_vector) return csft_vector is
		variable tmp : csft_vector;
	begin
		for idx in tmp'range loop
			tmp(idx) := (not val(idx).sgn, val(idx).mag);
		end loop;
		return tmp;
	end function;
begin
	loc_rden <= not cnp_busy;
	loc_inst : entity work.loc_vector
		port map (clock,
			loc_wren, loc_rden,
			loc_wpos, loc_rpos,
			loc_ioff, loc_ooff,
			loc_ishi, loc_oshi);

	wdf_rden <= not cnp_busy;
	wdf_inst : entity work.wdf_vector
		port map (clock,
			wdf_wren, wdf_rden,
			wdf_wpos, wdf_rpos,
			wdf_iwdf, wdf_owdf);

	var_rden <= not cnp_busy;
	var_inst : entity work.var_vector
		generic map (code_vectors)
		port map (clock,
			var_wren, var_rden,
			var_wpos, var_rpos,
			var_isft, var_osft);

	cnt_inst : entity work.cnt_vector
		port map (clock, cnt_wren,
			cnt_wpos, cnt_rpos,
			cnt_icnt, cnt_ocnt);

	bnl_rden <= not cnp_busy;
	bnl_inst : entity work.bnl_vector
		generic map (locations_max)
		port map (clock,
			bnl_wren, bnl_rden,
			bnl_wpos, bnl_rpos,
			bnl_isft, bnl_osft);

	cnp_inst : entity work.cnp_vector
		port map (clock,
			cnp_start, cnp_count,
			cnp_busy, cnp_valid,
			cnp_iseq, cnp_oseq,
			cnp_ivsft, cnp_ovsft,
			cnp_ocsft,
			cnp_iwdf, cnp_owdf,
			cnp_iloc, cnp_oloc,
			cnp_ioff, cnp_ooff,
			cnp_ishi, cnp_oshi);

	rol_inst : entity work.rol_vector
		port map (clock, true,
			rol_shift,
			rol_ivsft, rol_ovsft);

	ror_clken <= not cnp_busy;
	ror_inst : entity work.ror_vector
		port map (clock, ror_clken,
			ror_shift,
			ror_ivsft, ror_ovsft);

	sub_clken <= not cnp_busy;
	inv_sub_icsft <= inv(sub_icsft);
	sub_inst : entity work.add_vector
		port map (clock, sub_clken,
			sub_ivsft, inv_sub_icsft,
			sub_ovsft);

	add_inst : entity work.add_vector
		port map (clock, true,
			add_ivsft, add_icsft,
			add_ovsft);

	process (clock)
	begin
		if rising_edge(clock) then
			if istart then
				swap_cv <= 0;
				swap_bv <= 0;
				swap_vs <= 0;
				swap_start_d(1) <= prev_start;
				prev_start <= istart;
				swap_stage(0) <= true;
			elsif swap_cv /= code_vectors then
				swap_start_d(1) <= false;
				if swap_bv = block_vectors-1 then
					swap_bv <= 0;
					if swap_vs = vector_scalars-1 then
						swap_vs <= 0;
						swap_cv <= swap_cv + block_vectors;
					else
						swap_vs <= swap_vs + 1;
					end if;
				else
					swap_bv <= swap_bv + 1;
				end if;
				if swap_cv = code_vectors-block_vectors and swap_bv = block_vectors-2 and swap_vs = vector_scalars-1 then
					busy <= true;
				end if;
				if swap_cv = code_vectors-block_vectors and swap_bv = block_vectors-1 and swap_vs = vector_scalars-1 then
					swap_stage(0) <= false;
				end if;
			end if;

			if swap_stage(0) then
				swap_vs_d(1) <= swap_vs;
				swap_start_d(2) <= swap_start_d(1);
				swap_soft_d(1) <= isoft;
				swap_pos <= swap_cv + swap_bv;
				var_rpos <= swap_cv + swap_bv;
			end if;

			swap_stage(1) <= swap_stage(0);
			if swap_stage(1) then
				swap_vs_d(2) <= swap_vs_d(1);
				ostart <= swap_start_d(2);
				swap_soft_d(2) <= swap_soft_d(1);
				swap_dpos <= swap_pos;
			end if;

			swap_stage(2) <= swap_stage(1);
			if swap_stage(2) then
				osoft <= vsft_to_soft(var_osft(swap_vs_d(2)));
				var_wren <= true;
				var_wpos <= swap_dpos;
				for idx in soft_vector'range loop
					if swap_vs_d(2) = idx then
						var_isft(idx) <= soft_to_vsft(swap_soft_d(2));
					else
						var_isft(idx) <= var_osft(idx);
					end if;
				end loop;
			end if;

			swap_stage(3) <= swap_stage(2);
			if swap_stage(3) and not swap_stage(2) then
				var_wren <= false;
				inp_stage(0) <= true;
--				busy <= false;
			end if;

			if inp_stage(0) then
				if not cnp_busy then
					if inp_num = inp_cnt then
						inp_num <= 0;
						inp_cnt <= cnt_ocnt;
						if inp_pty+1 = ptys then
							if inp_seq+1 = iterations_max then
								inp_stage(0) <= false;
							else
								inp_seq <= inp_seq + 1;
								inp_pty <= 0;
							end if;
						else
							inp_pty <= inp_pty + 1;
						end if;
					else
						inp_num <= inp_num + 1;
					end if;
					if inp_num = 0 then
						if inp_pty = 0 then
							inp_loc <= 0;
						end if;
					elsif inp_loc+1 /= locations_max-1 then
						inp_loc <= inp_loc + 1;
					end if;
					if inp_num = 0 then
						if inp_pty+1 = ptys then
							cnt_rpos <= 0;
						elsif cnt_rpos+1 /= parities_max-1 then
							cnt_rpos <= cnt_rpos + 1;
						end if;
					end if;
				end if;
			else
				cnt_rpos <= 0;
				inp_cnt <= cnt_ocnt;
				inp_num <= 0;
				inp_pty <= 0;
				inp_seq <= 0;
				inp_loc <= 0;
			end if;

--			report boolean'image(inp_stage(0)) & HT & boolean'image(cnp_busy) & HT & integer'image(inp_seq) & HT & integer'image(inp_cnt) & HT & integer'image(inp_num) & HT & integer'image(inp_loc) & HT & integer'image(inp_pty);

			if inp_stage(0) and not cnp_busy then
				loc_rpos <= inp_loc;
				wdf_rpos <= inp_loc;
				inp_num_d(1) <= inp_num;
				inp_cnt_d(1) <= inp_cnt;
				inp_seq_d(1) <= inp_seq;
				inp_loc_d(1) <= inp_loc;
			end if;

			inp_stage(1) <= inp_stage(0);
			if inp_stage(1) and not cnp_busy then
				inp_num_d(2) <= inp_num_d(1);
				inp_cnt_d(2) <= inp_cnt_d(1);
				inp_seq_d(2) <= inp_seq_d(1);
				inp_loc_d(2) <= inp_loc_d(1);
			end if;

			inp_stage(2) <= inp_stage(1);
			if inp_stage(2) and not cnp_busy then
				var_rpos <= loc_ooff;
				if inp_seq_d(2) = 0 then
					if inp_num_d(2) = 1 then
						inp_wdf_d(1) <= false;
					else
						inp_wdf_d(1) <= inp_off_d(1) = loc_ooff;
					end if;
				else
					inp_wdf_d(1) <= wdf_owdf;
				end if;
				inp_num_d(3) <= inp_num_d(2);
				inp_cnt_d(3) <= inp_cnt_d(2);
				inp_seq_d(3) <= inp_seq_d(2);
				inp_loc_d(3) <= inp_loc_d(2);
				inp_off_d(1) <= loc_ooff;
				inp_shi_d(1) <= loc_oshi;
			end if;

			inp_stage(3) <= inp_stage(2);
			if inp_stage(3) and not cnp_busy then
				if inp_num_d(3) = 1 then
					first_wdf <= inp_wdf_d(1);
				elsif inp_num_d(3) /= 0 then
					wdf_wren <= true;
					wdf_wpos <= inp_loc_d(4);
					if inp_off_d(2) = inp_off_d(1) then
						wdf_iwdf <= inp_wdf_d(1);
					else
						wdf_iwdf <= first_wdf;
						first_wdf <= inp_wdf_d(1);
					end if;
				end if;
				inp_num_d(4) <= inp_num_d(3);
				inp_cnt_d(4) <= inp_cnt_d(3);
				inp_seq_d(4) <= inp_seq_d(3);
				inp_loc_d(4) <= inp_loc_d(3);
				inp_wdf_d(2) <= inp_wdf_d(1);
				inp_off_d(2) <= inp_off_d(1);
				inp_shi_d(2) <= inp_shi_d(1);
			end if;

			inp_stage(4) <= inp_stage(3);
			if inp_stage(4) and not cnp_busy then
				if inp_num_d(4) = inp_cnt_d(4) then
					wdf_wpos <= inp_loc_d(4);
					wdf_iwdf <= first_wdf;
				end if;
				ror_shift <= inp_shi_d(2);
				ror_ivsft <= var_osft;
				bnl_rpos <= inp_loc_d(4);
				inp_num_d(5) <= inp_num_d(4);
				inp_cnt_d(5) <= inp_cnt_d(4);
				inp_seq_d(5) <= inp_seq_d(4);
				inp_loc_d(5) <= inp_loc_d(4);
				inp_wdf_d(3) <= inp_wdf_d(2);
				inp_off_d(3) <= inp_off_d(2);
				inp_shi_d(3) <= inp_shi_d(2);
			end if;

			inp_stage(5) <= inp_stage(4);
			if inp_stage(5) and not cnp_busy then
				if inp_num_d(5) = inp_cnt_d(5) then
					wdf_wren <= false;
				end if;
				inp_num_d(6) <= inp_num_d(5);
				inp_cnt_d(6) <= inp_cnt_d(5);
				inp_seq_d(6) <= inp_seq_d(5);
				inp_loc_d(6) <= inp_loc_d(5);
				inp_wdf_d(4) <= inp_wdf_d(3);
				inp_off_d(4) <= inp_off_d(3);
				inp_shi_d(4) <= inp_shi_d(3);
			end if;

			inp_stage(6) <= inp_stage(5);
			if inp_stage(6) and not cnp_busy then
				if inp_off_d(4) = code_vectors-1 and inp_shi_d(4) = 1 then
					prev_vsft <= ror_ovsft(vsft_vector'low);
					sub_ivsft <= soft_to_vsft(vmag_scalar'high) & ror_ovsft(vsft_vector'low+1 to vsft_vector'high);
				else
					sub_ivsft <= ror_ovsft;
				end if;
				if inp_seq_d(6) = 0 then
					sub_icsft <= (others => (false, 0));
				else
					sub_icsft <= bnl_osft;
				end if;
				inp_num_d(7) <= inp_num_d(6);
				inp_cnt_d(7) <= inp_cnt_d(6);
				inp_seq_d(7) <= inp_seq_d(6);
				inp_loc_d(7) <= inp_loc_d(6);
				inp_wdf_d(5) <= inp_wdf_d(4);
				inp_off_d(5) <= inp_off_d(4);
				inp_shi_d(5) <= inp_shi_d(4);
			end if;

			inp_stage(7) <= inp_stage(6);
			if inp_stage(7) and not cnp_busy then
				inp_num_d(8) <= inp_num_d(7);
				inp_cnt_d(8) <= inp_cnt_d(7);
				inp_seq_d(8) <= inp_seq_d(7);
				inp_loc_d(8) <= inp_loc_d(7);
				inp_wdf_d(6) <= inp_wdf_d(5);
				inp_off_d(6) <= inp_off_d(5);
				inp_shi_d(6) <= inp_shi_d(5);
			end if;

			inp_stage(8) <= inp_stage(7);
			if inp_stage(8) and not cnp_busy then
				cnp_start <= inp_num_d(8) = 0;
				cnp_count <= inp_cnt_d(8);
				cnp_ivsft <= sub_ovsft;
				cnp_iseq <= inp_seq_d(8);
				cnp_iloc <= inp_loc_d(8);
				cnp_iwdf <= inp_wdf_d(6);
				cnp_ioff <= inp_off_d(6);
				cnp_ishi <= inp_shi_d(6);
			end if;

--			report boolean'image(cnp_start) & HT & boolean'image(cnp_busy) & HT & integer'image(cnp_iseq) & HT & integer'image(cnp_iloc) & HT & integer'image(cnp_ioff) & HT & integer'image(cnp_ishi) & HT & boolean'image(cnp_iwdf) & HT & integer'image(cnp_count) & HT &
--				integer'image(vsft_to_soft(cnp_ivsft(0))) & HT & integer'image(vsft_to_soft(cnp_ivsft(1))) & HT & integer'image(vsft_to_soft(cnp_ivsft(2))) & HT & integer'image(vsft_to_soft(cnp_ivsft(3))) & HT & integer'image(vsft_to_soft(cnp_ivsft(4)));

--			report boolean'image(cnp_valid) & HT & boolean'image(cnp_busy) & HT & integer'image(cnp_oseq) & HT & integer'image(cnp_oloc) & HT & integer'image(cnp_ooff) & HT & integer'image(cnp_oshi) & HT & boolean'image(cnp_owdf) & HT &
--				integer'image(vsft_to_soft(cnp_ovsft(0))) & HT & integer'image(vsft_to_soft(cnp_ovsft(1))) & HT & integer'image(vsft_to_soft(cnp_ovsft(2))) & HT & integer'image(vsft_to_soft(cnp_ovsft(3))) & HT & integer'image(vsft_to_soft(cnp_ovsft(4))) & HT &
--				integer'image(csft_to_soft(cnp_ocsft(0))) & HT & integer'image(csft_to_soft(cnp_ocsft(1))) & HT & integer'image(csft_to_soft(cnp_ocsft(2))) & HT & integer'image(csft_to_soft(cnp_ocsft(3))) & HT & integer'image(csft_to_soft(cnp_ocsft(4)));

			if cnp_valid then
				add_ivsft <= cnp_ovsft;
				add_icsft <= cnp_ocsft;
				out_wdf_d(1) <= cnp_owdf;
				out_off_d(1) <= cnp_ooff;
				out_shi_d(1) <= cnp_oshi;
				bnl_wpos <= cnp_oloc;
				bnl_wren <= cnp_oseq = 0 or not cnp_owdf;
				if not cnp_owdf then
					bnl_isft <= cnp_ocsft;
				elsif cnp_oseq = 0 then
					bnl_isft <= (others => (false, 0));
				end if;
			else
				bnl_wren <= false;
			end if;

			out_stage(1) <= cnp_valid;
			if out_stage(1) then
				out_off_d(2) <= out_off_d(1);
				out_shi_d(2) <= out_shi_d(1);
				out_wdf_d(2) <= out_wdf_d(1);
			end if;

			out_stage(2) <= out_stage(1);
			if out_stage(2) then
				rol_shift <= out_shi_d(2);
				if out_off_d(2) = code_vectors-1 and out_shi_d(2) = 1 then
					rol_ivsft <= prev_vsft & add_ovsft(vsft_vector'low+1 to vsft_vector'high);
				else
					rol_ivsft <= add_ovsft;
				end if;
				out_off_d(3) <= out_off_d(2);
				out_wdf_d(3) <= out_wdf_d(2);
			end if;

			out_stage(3) <= out_stage(2);
			if out_stage(3) then
				out_off_d(4) <= out_off_d(3);
				out_wdf_d(4) <= out_wdf_d(3);
			end if;

			out_stage(4) <= out_stage(3);
			if out_stage(4) then
				var_isft <= rol_ovsft;
				var_wpos <= out_off_d(4);
				var_wren <= not out_wdf_d(4);
			end if;

			out_stage(5) <= out_stage(4);
			if out_stage(5) and not out_stage(4) then
				var_wren <= false;
				if not inp_stage(inp_stage'high) and not cnp_busy then
					busy <= false;
				end if;
			end if;
		end if;
	end process;
end rtl;

