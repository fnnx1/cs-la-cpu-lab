.PHONY: test

test:
	cp -f for_test_obj/ex$(ex)_obj/* cdp_ede_local-master/mycpu_env/func/obj/
	cd cdp_ede_local-master/mycpu_env/gettrace && make clean && make iverilog
	cd cdp_ede_local-master/mycpu_env/soc_verify/soc_bram/testbench && make clean && make iverilog
