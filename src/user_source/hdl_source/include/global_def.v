
`define   DATA_WIDTH                        32
`define   ADDR_WIDTH                        21
`define   DM_WIDTH                          4
`define   ROW_WIDTH                        11
`define   BA_WIDTH                        2
`define	  SDR_CLK_PERIOD				1000000000/49500000
// EM638325 requires 4096 refresh commands per 64 ms (not ROW_COUNT).
// Integer truncation gives 773 clocks at 49.5 MHz, below 15.625 us.
`define   SELF_REFRESH_INTERVAL            (49500000/1000*64/4096)
