--Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
--Date        : Sat May  7 20:36:51 2022
--Host        : MSI running 64-bit major release  (build 9200)
--Command     : generate_target soc_wrapper.bd
--Design      : soc_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity soc_wrapper is
  port (
    ARST_AVL_N : out STD_LOGIC_VECTOR ( 0 to 0 );
    CLK_AVL : out STD_LOGIC;
    M_AVALON_address : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AVALON_byteenable : out STD_LOGIC_VECTOR ( 3 downto 0 );
    M_AVALON_read : out STD_LOGIC;
    M_AVALON_readdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AVALON_readdatavalid : in STD_LOGIC;
    M_AVALON_waitrequest : in STD_LOGIC;
    M_AVALON_write : out STD_LOGIC;
    M_AVALON_writedata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AVALON_address : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AVALON_burstcount : in STD_LOGIC_VECTOR ( 10 downto 0 );
    S_AVALON_read : in STD_LOGIC;
    S_AVALON_readdata : out STD_LOGIC_VECTOR ( 63 downto 0 );
    S_AVALON_readdatavalid : out STD_LOGIC;
    S_AVALON_waitrequest : out STD_LOGIC;
    S_AVALON_write : in STD_LOGIC;
    S_AVALON_writedata : in STD_LOGIC_VECTOR ( 63 downto 0 )
  );
end soc_wrapper;

architecture STRUCTURE of soc_wrapper is
  component soc is
  port (
    CLK_AVL : out STD_LOGIC;
    ARST_AVL_N : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AVALON_address : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AVALON_byteenable : out STD_LOGIC_VECTOR ( 3 downto 0 );
    M_AVALON_read : out STD_LOGIC;
    M_AVALON_readdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AVALON_readdatavalid : in STD_LOGIC;
    M_AVALON_waitrequest : in STD_LOGIC;
    M_AVALON_write : out STD_LOGIC;
    M_AVALON_writedata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AVALON_address : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AVALON_burstcount : in STD_LOGIC_VECTOR ( 10 downto 0 );
    S_AVALON_read : in STD_LOGIC;
    S_AVALON_readdata : out STD_LOGIC_VECTOR ( 63 downto 0 );
    S_AVALON_readdatavalid : out STD_LOGIC;
    S_AVALON_waitrequest : out STD_LOGIC;
    S_AVALON_write : in STD_LOGIC;
    S_AVALON_writedata : in STD_LOGIC_VECTOR ( 63 downto 0 )
  );
  end component soc;
begin
soc_i: component soc
     port map (
      ARST_AVL_N(0) => ARST_AVL_N(0),
      CLK_AVL => CLK_AVL,
      M_AVALON_address(31 downto 0) => M_AVALON_address(31 downto 0),
      M_AVALON_byteenable(3 downto 0) => M_AVALON_byteenable(3 downto 0),
      M_AVALON_read => M_AVALON_read,
      M_AVALON_readdata(31 downto 0) => M_AVALON_readdata(31 downto 0),
      M_AVALON_readdatavalid => M_AVALON_readdatavalid,
      M_AVALON_waitrequest => M_AVALON_waitrequest,
      M_AVALON_write => M_AVALON_write,
      M_AVALON_writedata(31 downto 0) => M_AVALON_writedata(31 downto 0),
      S_AVALON_address(31 downto 0) => S_AVALON_address(31 downto 0),
      S_AVALON_burstcount(10 downto 0) => S_AVALON_burstcount(10 downto 0),
      S_AVALON_read => S_AVALON_read,
      S_AVALON_readdata(63 downto 0) => S_AVALON_readdata(63 downto 0),
      S_AVALON_readdatavalid => S_AVALON_readdatavalid,
      S_AVALON_waitrequest => S_AVALON_waitrequest,
      S_AVALON_write => S_AVALON_write,
      S_AVALON_writedata(63 downto 0) => S_AVALON_writedata(63 downto 0)
    );
end STRUCTURE;
