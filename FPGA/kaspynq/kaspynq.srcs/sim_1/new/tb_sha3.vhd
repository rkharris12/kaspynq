----------------------------------------------------------------------------------
-- Richie Harris
-- rkharris12@gmail.com
-- 5/6/2022
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.STOP;

entity tb_sha3 is
    
end tb_sha3;

architecture sim of tb_sha3 is

    component sha3 is
        generic (
            G_NUM_PARALLEL_F : integer
        );
        port (
            CLK        : in  std_logic;
            ARST_N     : in  std_logic;
            DIN_PAD    : in  std_logic_vector(1087 downto 0);
            DIN_PAD_EN : in  std_logic;
            DOUT       : out std_logic_vector(255 downto 0);
            DOUT_EN    : out std_logic
        );
    end component;

    function rev_byte_order(
        rev_input : std_logic_vector)
        return std_logic_vector is
        variable temp : std_logic_vector(rev_input'length - 1 downto 0);
    begin
        for byte in 0 to (rev_input'length/8)-1 loop
            temp(8*((rev_input'length/8)-byte)-1 downto 8*((rev_input'length/8)-(byte+1))) := rev_input(8*(byte+1)-1 downto 8*byte);
        end loop;
        return temp;
    end rev_byte_order;

    constant C_CLK_PERIOD : time := 10 ns; -- 100 MHz

    signal clk            : std_logic := '1';
    signal arst_n         : std_logic := '0';

    signal din_pad_en     : std_logic;
    signal din_pad        : std_logic_vector(1087 downto 0);
    signal dout           : std_logic_vector(255 downto 0);
    signal dout_en        : std_logic;

begin

    -- clk and arst_n
    clk    <= not clk after C_CLK_PERIOD/2;
    arst_n <= '1' after 10*C_CLK_PERIOD;

    -- send input data
    process begin
        din_pad_en <= '0';
        din_pad    <= (others => '0');

        wait for 20*C_CLK_PERIOD;

        din_pad_en    <= '1';
        din_pad(1)    <= '1';
        din_pad(2)    <= '1';
        din_pad(1087) <= '1';
        
        wait for 2*C_CLK_PERIOD;

        din_pad_en <= '0';

        wait until (dout_en = '1');
        wait until (dout_en = '0');
        report "hash: 0x" & to_hstring(rev_byte_order(dout)); -- for easy comparison since lsb is printed first
        stop;
    end process;

    -- instantiate hasher
    uut : sha3
        generic map (
            G_NUM_PARALLEL_F => 24)
        port map (
            CLK        => clk,
            ARST_N     => arst_n,
            DIN_PAD    => din_pad,
            DIN_PAD_EN => din_pad_en,
            DOUT       => dout,
            DOUT_EN    => dout_en);

end sim;
