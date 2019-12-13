
GHDL = ghdl
LP_SOLVE = lp_solve

.PHONY: vector
vector: cnp_vector_tb_exp.txt dec_vector_tb_exp.txt cnp_vector_tb_out.txt dec_vector_tb_out.txt

.PHONY: scalar
scalar: cnp_scalar_tb_exp.txt dec_scalar_tb_exp.txt cnp_scalar_tb_out.txt dec_scalar_tb_out.txt

.PHONY: all
all: scalar vector

.PHONY: vcd
vcd: cnp_scalar_tb.vcd dec_scalar_tb.vcd

.PHONY: table
table: table_input.txt work/generate_table_model_txt work/generate_table_vector_txt
	work/generate_table_model_txt
	$(LP_SOLVE) table_model.txt > table_solution.txt
	work/generate_table_vector_txt

.PRECIOUS: cnp_scalar_tb_out.txt
cnp_scalar_tb_out.txt: cnp_scalar_tb cnp_scalar_tb_inp.txt
	$(GHDL) -r --workdir=work $<

.PRECIOUS: cnp_vector_tb_out.txt
cnp_vector_tb_out.txt: cnp_vector_tb cnp_vector_tb_inp.txt
	$(GHDL) -r --workdir=work $<

.PRECIOUS: dec_scalar_tb_out.txt
dec_scalar_tb_out.txt: dec_scalar_tb dec_scalar_tb_inp.txt
	$(GHDL) -r --workdir=work $<

.PRECIOUS: dec_vector_tb_out.txt
dec_vector_tb_out.txt: dec_vector_tb dec_vector_tb_inp.txt
	$(GHDL) -r --workdir=work $<

.PRECIOUS: cnp_scalar_tb.vcd
cnp_scalar_tb.vcd: cnp_scalar_tb cnp_scalar_tb_inp.txt
	$(GHDL) -r --workdir=work $< --vcd=$@

.PRECIOUS: cnp_vector_tb.vcd
cnp_vector_tb.vcd: cnp_vector_tb cnp_vector_tb_inp.txt
	$(GHDL) -r --workdir=work $< --vcd=$@

.PRECIOUS: dec_scalar_tb.vcd
dec_scalar_tb.vcd: dec_scalar_tb dec_scalar_tb_inp.txt
	$(GHDL) -r --workdir=work $< --vcd=$@

.PRECIOUS: dec_vector_tb.vcd
dec_vector_tb.vcd: dec_vector_tb dec_vector_tb_inp.txt
	$(GHDL) -r --workdir=work $< --vcd=$@

work/ldpc_scalar.o: ldpc_scalar.vhd
work/ldpc_vector.o: ldpc_vector.vhd work/ldpc_scalar.o
work/table_vector.o: table_vector.vhd work/ldpc_scalar.o work/ldpc_vector.o
work/add_scalar.o: add_scalar.vhd work/ldpc_scalar.o
work/add_vector.o: add_vector.vhd work/ldpc_vector.o work/add_scalar.o
work/bnl_scalar.o: bnl_scalar.vhd work/ldpc_scalar.o work/ldpc_scalar.o
work/bnl_vector.o: bnl_vector.vhd work/ldpc_vector.o work/bnl_scalar.o
work/cnt_vector.o: cnt_vector.vhd work/ldpc_scalar.o work/ldpc_vector.o work/table_vector.o
work/buf_scalar.o: buf_scalar.vhd work/ldpc_scalar.o
work/fub_scalar.o: fub_scalar.vhd work/ldpc_scalar.o
work/buf_vector.o: buf_vector.vhd work/ldpc_vector.o work/ldpc_scalar.o work/fub_scalar.o
work/loc_vector.o: loc_vector.vhd work/ldpc_vector.o work/table_vector.o
work/rol_vector.o: rol_vector.vhd work/ldpc_vector.o
work/ror_vector.o: ror_vector.vhd work/ldpc_vector.o
work/var_scalar.o: var_scalar.vhd work/ldpc_scalar.o
work/var_vector.o: var_vector.vhd work/ldpc_vector.o work/var_scalar.o
work/wdf_vector.o: wdf_vector.vhd work/ldpc_vector.o
work/cnp_scalar.o: cnp_scalar.vhd work/ldpc_scalar.o work/buf_scalar.o
work/cnp_vector.o: cnp_vector.vhd work/ldpc_scalar.o work/ldpc_vector.o work/buf_vector.o
work/dec_scalar.o: dec_scalar.vhd work/ldpc_scalar.o work/table_scalar.o work/loc_scalar.o work/var_scalar.o work/cnt_scalar.o work/bnl_scalar.o work/cnp_scalar.o work/add_scalar.o
work/dec_vector.o: dec_vector.vhd work/ldpc_scalar.o work/ldpc_vector.o work/table_vector.o work/loc_vector.o work/wdf_vector.o work/var_vector.o work/cnt_vector.o work/bnl_vector.o work/cnp_vector.o work/rol_vector.o work/ror_vector.o work/add_vector.o work/add_vector.o
work/cnp_scalar_tb.o: cnp_scalar_tb.vhd work/ldpc_scalar.o work/cnp_scalar.o
work/cnp_vector_tb.o: cnp_vector_tb.vhd work/ldpc_scalar.o work/ldpc_vector.o work/cnp_vector.o
work/dec_scalar_tb.o: dec_scalar_tb.vhd work/ldpc_scalar.o work/dec_scalar.o
work/dec_vector_tb.o: dec_vector_tb.vhd work/ldpc_scalar.o work/dec_vector.o

work/%.o: %.vhd | work
	$(GHDL) -a --workdir=work $<

cnp_scalar_tb: work/cnp_scalar_tb.o
cnp_vector_tb: work/cnp_vector_tb.o
dec_scalar_tb: work/dec_scalar_tb.o
dec_vector_tb: work/dec_vector_tb.o

%_tb: work/%_tb.o | work
	$(GHDL) -e --workdir=work $@

work/check_table_scalar_txt: check_table_scalar_txt.cc ldpc_scalar.hh
work/check_table_vector_txt: check_table_vector_txt.cc ldpc_scalar.hh ldpc_vector.hh
work/generate_cnp_scalar_tb_inp_txt: generate_cnp_scalar_tb_inp_txt.cc ldpc_scalar.hh
work/generate_cnp_vector_tb_inp_txt: generate_cnp_vector_tb_inp_txt.cc ldpc_scalar.hh ldpc_vector.hh
work/generate_dec_scalar_tb_inp_txt: generate_dec_scalar_tb_inp_txt.cc ldpc_scalar.hh
work/generate_dec_vector_tb_inp_txt: generate_dec_vector_tb_inp_txt.cc ldpc_scalar.hh ldpc_vector.hh
work/generate_cnp_scalar_tb_exp_txt: generate_cnp_scalar_tb_exp_txt.cc ldpc_scalar.hh cnp_scalar.hh exclusive_reduce.hh
work/generate_cnp_vector_tb_exp_txt: generate_cnp_vector_tb_exp_txt.cc ldpc_scalar.hh ldpc_vector.hh cnp_scalar.hh cnp_vector.hh exclusive_reduce.hh
work/generate_dec_scalar_tb_exp_txt: generate_dec_scalar_tb_exp_txt.cc ldpc_scalar.hh dec_scalar.hh cnp_scalar.hh exclusive_reduce.hh
work/generate_dec_vector_tb_exp_txt: generate_dec_vector_tb_exp_txt.cc ldpc_scalar.hh ldpc_vector.hh dec_vector.hh cnp_scalar.hh cnp_vector.hh exclusive_reduce.hh
work/generate_table_scalar_vhd: generate_table_scalar_vhd.cc ldpc_scalar.hh
work/generate_table_vector_vhd: generate_table_vector_vhd.cc ldpc_scalar.hh ldpc_vector.hh
work/generate_table_model_txt: generate_table_model_txt.cc ldpc_scalar.hh ldpc_vector.hh
work/generate_table_vector_txt: generate_table_vector_txt.cc ldpc_scalar.hh ldpc_vector.hh

work/%: %.cc | work
	$(CXX) $< -o $@

cnp_scalar_tb_inp.txt: work/generate_cnp_scalar_tb_inp_txt
	work/generate_cnp_scalar_tb_inp_txt

cnp_vector_tb_inp.txt: work/generate_cnp_vector_tb_inp_txt
	work/generate_cnp_vector_tb_inp_txt

cnp_scalar_tb_exp.txt: cnp_scalar_tb_inp.txt work/generate_cnp_scalar_tb_exp_txt
	work/generate_cnp_scalar_tb_exp_txt

cnp_vector_tb_exp.txt: cnp_vector_tb_inp.txt work/generate_cnp_vector_tb_exp_txt
	work/generate_cnp_vector_tb_exp_txt

dec_scalar_tb_inp.txt: work/generate_dec_scalar_tb_inp_txt
	work/generate_dec_scalar_tb_inp_txt

dec_vector_tb_inp.txt: work/generate_dec_vector_tb_inp_txt
	work/generate_dec_vector_tb_inp_txt

dec_scalar_tb_exp.txt: dec_scalar_tb_inp.txt table_scalar.txt work/generate_dec_scalar_tb_exp_txt
	work/generate_dec_scalar_tb_exp_txt

dec_vector_tb_exp.txt: dec_vector_tb_inp.txt table_vector.txt work/generate_dec_vector_tb_exp_txt
	work/generate_dec_vector_tb_exp_txt

table_scalar.vhd: table_scalar.txt work/check_table_scalar_txt work/generate_table_scalar_vhd
	work/check_table_scalar_txt
	work/generate_table_scalar_vhd

table_vector.vhd: table_vector.txt work/check_table_vector_txt work/generate_table_vector_vhd
	work/check_table_vector_txt
	work/generate_table_vector_vhd

work:
	mkdir $@

.PHONY: clean
clean:
	rm -rf work *.o *_tb *_tb_inp.txt *_tb_out.txt *_tb_exp.txt *.vcd table_model.txt table_solution.txt

