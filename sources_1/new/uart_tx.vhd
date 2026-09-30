library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;


entity uart_tx is
    port (
        clk : in std_logic;
        reset : in std_logic;
        start_i : in std_logic;
        data_i : in std_logic_vector(7 downto 0); -- 0 to 255 integer from file
        tx_done : out std_logic;
        data_o : out std_logic -- data to uart_rx
    );
end uart_tx;

architecture rtl of uart_tx is
    type state_t is (IDLE, START, DATA, STOP);
    signal state_r : state_t := IDLE;

    signal index : integer := 0;
    signal baud_cnt : integer := 0;
    constant BAUD_DIV : integer := 868;
begin
    process(clk) 
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                tx_done <= '0';
                data_o <= '1';
                tx_done <= '0';
                index <= 0;
                baud_cnt <= 0;
            else
                tx_done <= '0';
                if (start_i = '1') then
                    state_r <= START;
                end if;
                
                if (baud_cnt < BAUD_DIV - 1) then
                    baud_cnt <= baud_cnt + 1;
                else
                    baud_cnt <= 0;
                    
                    case state_r is 
                        when IDLE =>
                            data_o <= '1';
                            
                        when START =>
                            data_o <= '0'; -- start bit
                            index <= 0;
                            state_r <= DATA;
                            
                        when DATA =>
                            data_o <= data_i(index);
                            
                            if (index = 7) then
                                state_r <= STOP;
                            else 
                                index <= index + 1;
                            end if;
                            
                        when STOP =>
                            data_o <= '1';
                            tx_done <= '1';
                            state_r <= IDLE;
                            
                        when others =>
                            state_r <= IDLE;
                            
                    end case; 
                end if;
            end if;
        end if;
    end process;

end rtl;
